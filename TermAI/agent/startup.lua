-- startup.lua — Fachada + Loop de replay do histórico ao iniciar a TUI.
-- v2: Restaura tool_calls/tool_call_id; replay de native tool calls.
-- v2.4: usa ui.tool_replay (estado final direto, sem fase amarela/cursor-up) —
--       evita corrupção visual quando um turno tem múltiplas tool_calls.
-- v2.5: agrupa Read consecutivos no replay também (via tc_mapper.lua).
-- v5: reconstrói e expande pasted_texts na memória do agente.
-- v5.1: escapa o caractere especial % no gsub para prevenir crash de inicialização.
local ui      = require("ui")
local session = require("session")
local api     = require("agent.api")
local core    = require("ui.core")
local c       = core.c
local rr      = require("agent.startup.reasoning_renderer")
local classif = require("agent.startup.message_classifier")
local tcm     = require("agent.startup.tc_mapper")
local M = {}
local REPLAY_N = 40
function M.run(ctx, reset_info)
  io.write(c.cls .. "\27[3J")
  ui.header(ctx.active.name or ctx.active.ref, session.current())
  if reset_info then
    local reason = reset_info.reason == "daily" and "diário" or "por inatividade"
    io.write("\27[38;5;245m↻ Reset automático (" .. reason .. "): "
      .. reset_info.from .. " → " .. reset_info.to .. "\27[0m\n\n")
    io.flush()
  end
  local _history = session.load_history()
  -- v2: restaura tool_calls e tool_call_id — contexto correto para a API.
  -- Antes, esses campos eram descartados, deixando role="tool" sem tool_call_id
  -- e assistant messages sem tool_calls (contexto inválido per protocolo OpenAI).
  -- v5: reconstrói e expande os metadados dos pasted_texts na memória do agente usando o regex seguro
  for _, msg in ipairs(_history) do
    local content = msg.content or ""
    if msg.pasted_texts then
      for idx, raw_text in pairs(msg.pasted_texts) do
        -- Escapa o caractere % duplicando-o para evitar erro de sintaxe no gsub do Lua
        local safe_text = raw_text:gsub("%%", "%%%%")
        content = content:gsub("%[pasted_text#" .. idx .. "[^%]]*%]", safe_text)
      end
    end
    local e = { role = msg.role, content = content }
    if msg.tool_calls   then e.tool_calls   = msg.tool_calls   end
    if msg.tool_call_id then e.tool_call_id = msg.tool_call_id end
    ctx.msgs[#ctx.msgs + 1] = e
  end
  -- REQ-5: restaura Workspace Attention cumulativo da última compactação
  if _history._session_files then
    ctx.session_files = _history._session_files
  end
    if #_history > 0 then
      local st, st_fresh = session.load_session_tokens()
      if st > 0 and st_fresh then
        -- T6: valor fresco do provider — confiável, usa direto
        ctx.tokens = st
      elseif st > 0 then
        -- T6: valor não fresco (fallback) — compara com estimativa, usa o maior
        local estimated = api.estimate_tokens(ctx.msgs)
        ctx.tokens = st > estimated and st or estimated
      else
        -- T6: nenhum valor salvo — usa estimativa
        ctx.tokens = api.estimate_tokens(ctx.msgs)
      end
    end
  if #_history == 0 then return end
  local total     = #_history
  local start_idx = math.max(1, total - REPLAY_N + 1)
  local tw        = core.tw()
  local tag       = " ⬡ " .. session.current() .. " "
  local dashes    = math.max(0, tw - #tag - 1)
  io.write("\27[38;5;238m"
    .. string.rep("─", math.floor(dashes / 2)) .. tag
    .. string.rep("─", dashes - math.floor(dashes / 2))
    .. "\27[0m\n\n")
  if start_idx > 1 then
    io.write("\27[38;5;245m ··· " .. (start_idx - 1)
      .. " mensagens anteriores não exibidas\27[0m\n\n")
  end
  local last_tool_cmd  = nil
  local tc_id_map      = {}  -- tool_call_id → display string (tool individual)
  local tc_group_map   = {}  -- tool_call_id → {gid, size, name} (corrida de Read)
  local pending_groups = {}  -- gid → {names={}, oks={}, size=N}
  local function flush_group(gid)
    local g = pending_groups[gid]
    if g and #g.names > 0 then
      ui.tool_group_read_replay(g.names, g.oks)
      pending_groups[gid] = nil
    end
  end
  for i = start_idx, total do
    local msg = _history[i]
    if msg._compaction then
      last_tool_cmd, tc_id_map, tc_group_map, pending_groups = nil, {}, {}, {}
      local preview = msg.content or ""
      if #preview > 300 then preview = preview:sub(1, 297) .. "..." end
      io.write("\27[38;5;245m⟳ " .. preview .. "\27[0m\n\n")
    elseif msg.role == "assistant" and msg.tool_calls then
      -- v2.4/2.5: NÃO chama tool_start aqui — replay não anima "em progresso",
      -- só mapeia (individual ou agrupado) pro que vem depois usar.
      if msg._reasoning then rr.show_reasoning_box(msg._reasoning) end
      if msg.content and msg.content ~= "" then ui.ai_msg(msg.content) end
      last_tool_cmd = tcm.map_tool_calls(msg.tool_calls, tc_id_map, tc_group_map) or last_tool_cmd
    elseif msg.role == "tool" then
      -- v2.5: resolve por grupo primeiro; senão, individual (como já era).
      local ginfo = msg.tool_call_id and tc_group_map[msg.tool_call_id]
      if ginfo then
        local g = pending_groups[ginfo.gid]
        if not g then
          g = { names = {}, oks = {}, size = ginfo.size }
          pending_groups[ginfo.gid] = g
        end
        g.names[#g.names + 1] = ginfo.name
        g.oks[#g.oks + 1]     = not (msg.content or ""):match("^❌")
        if #g.names >= g.size then flush_group(ginfo.gid) end
      else
        local cmd = (msg.tool_call_id and tc_id_map[msg.tool_call_id])
                 or last_tool_cmd or "exec"
        ui.tool_replay(cmd, msg.content or "", not (msg.content or ""):match("^❌"))
        if not msg.tool_call_id then last_tool_cmd = nil end
      end
    else
      local kind, a, b, d = classif.classify(msg.role, msg.content)
      if kind == "skip" then
        -- v6: válvula de segurança — se a mensagem foi pulada por falta de conteúdo textual,
        -- mas continha raciocínio (reasoning), ainda exibe o box de pensamento.
        if msg._reasoning then
          last_tool_cmd, tc_id_map, tc_group_map, pending_groups = nil, {}, {}, {}
          rr.show_reasoning_box(msg._reasoning)
        end
      elseif kind == "user" then
        last_tool_cmd, tc_id_map, tc_group_map, pending_groups = nil, {}, {}, {}
        ui.user_msg(a, msg.pasted_texts)
      elseif kind == "assistant" then
        last_tool_cmd, tc_id_map, tc_group_map, pending_groups = nil, {}, {}, {}
        if msg._reasoning then rr.show_reasoning_box(msg._reasoning) end
        ui.ai_msg(a)
      elseif kind == "tool_call" then
        last_tool_cmd = a
      elseif kind == "tool_call_with_text" then
        last_tool_cmd = nil
        if msg._reasoning then rr.show_reasoning_box(msg._reasoning) end
        ui.ai_msg(b); last_tool_cmd = a
      elseif kind == "tool_result" then
        ui.tool_replay(last_tool_cmd or a, d, (b == "ok")); last_tool_cmd = nil
      end
    end
  end
  -- v2.5: flush de grupos que a janela do REPLAY_N cortou no meio — mostra
  -- o que tem em vez de descartar silenciosamente.
  for gid in pairs(pending_groups) do flush_group(gid) end
  io.write("\27[38;5;238m" .. string.rep("─", tw) .. "\27[0m\n\n")
  io.flush()
  local s = session.status and session.status() or nil
  local last_time = s and s.last_activity and s.last_activity ~= ""
    and s.last_activity:match("T(%d%d:%d%d)") or nil
  ui.footer(ctx.tokens, ctx.active.context_window, nil, last_time)
end
return M
