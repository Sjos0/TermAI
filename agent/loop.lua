-- agent/loop.lua — Loop ReAct do agente.
-- v3.0: Interrupção atômica de turnos por cancelamento e injeção invisível de System Messages de login, restart e cancelamento.
local ui          = require("ui")
local api         = require("agent.api")
local th          = require("agent.tools_handler")
local tool_runner = require("agent.loop.tool_runner")
local M           = {}

-- Sinalizador de boot (RAM-only): determina login vs restart no primeiro turno de rede
local is_first_turn = true

local _mem = (function()
  local ok, m = pcall(require, "tools.memory")
  return ok and m or nil
end)()

local function strip_flush_tag(text)
  return (text:gsub("%[FLUSH_DONE%]", ""):match("^%s*(.-)%s*$") or "")
end

-- v2.2: detecta resposta que anuncia uma ação mas não chama nenhuma tool
local function is_unfulfilled_intent(display_text)
  if not display_text or display_text == "" then return false end
  local trimmed = display_text:match("^%s*(.-)%s*$") or display_text
  return trimmed:sub(-1) == ":"
end

function M.rodar(ctx, input, role, max_iter)
  local cur_text   = input
  local cur_role   = role or "user"
  local iter       = 0
  local elapsed    = 0  -- Acumulado ao longo de TODAS as iterações do turno
                        -- (thinking + tool calls + resposta final), não só a última.
  local raw_limit  = max_iter or ctx.MAX_ITER
  local limit      = (raw_limit == 0) and math.huge or raw_limit
  local stream_complete   = true
  local last_reasoning    = ""
  local vazio_count       = 0
  local MAX_VAZIO_RETRIES = (ctx.cfg
    and ctx.cfg.agents
    and ctx.cfg.agents.defaults
    and ctx.cfg.agents.defaults.hooks
    and ctx.cfg.agents.defaults.hooks.max_vazio_retries) or 2
  local spinner_started = false

  -- Proteção contra loops redundantes: reinicia assinatura ao novo prompt do usuário
  if cur_role == "user" then
    ctx.last_tool_sig = nil
  end

  -- Injeção invisível de System Messages lógicas (Estilo Claude Code)
  if cur_role == "user" then
    local system_injections = {}

    -- 1. Detecção de Boot: Primeira chamada de rede da sessão Lua atual
    if is_first_turn then
      is_first_turn = false
      if #ctx.msgs <= 1 then
        system_injections[#system_injections + 1] = "[SYSTEM MESSAGE: User has joined the session. Ready for instructions.]"
      else
        system_injections[#system_injections + 1] = "[SYSTEM MESSAGE: System has restarted. Session state and working directory are preserved. Ready to continue.]"
      end
    end

    -- 2. Detecção de Cancelamento prévio no Prompt
    if ctx.prev_command_cancelled then
      ctx.prev_command_cancelled = nil
      system_injections[#system_injections + 1] = "[SYSTEM MESSAGE: The previous bash command/action was CANCELLED by the user. Modify your approach or ask for clarification.]"
    end

    if #system_injections > 0 then
      cur_text = table.concat(system_injections, "\n") .. "\n\n" .. cur_text
    end
  end

  if _mem and cur_role == "user" and cur_text and #cur_text > 2 then
    ui.start_thinking("Injetando")
    spinner_started = true
    local ok, mem = pcall(_mem.search, cur_text)
    if ok and mem
       and not mem:match("^❌")
       and not mem:match("^📭")
       and not mem:match("^🔍 Nenhuma") then
      cur_text = "[MEMÓRIA RELEVANTE — injetada automaticamente]\n"
               .. mem .. "\n---\n" .. cur_text
    end
    ui.update_label()
  end

  while iter < limit do
    if not spinner_started then ui.start_thinking() end
    spinner_started = false
    local resp, is_overflow, done_flag, reasoning, tool_calls =
      api.pensar_stream(ctx, cur_text, cur_role)
    elapsed = elapsed + ui.stop_thinking()
    if done_flag ~= nil then stream_complete = done_flag end
    if is_overflow then
      return resp, elapsed, false, true, stream_complete, ""
    end

    -- ── v2: Caminho nativo JSON ─────────────────────────────────────────
    if tool_calls and #tool_calls > 0 then
      local resp_stripped = strip_flush_tag(resp)
      if resp_stripped ~= "" then ui.ai_msg_stream(resp_stripped) end

      tool_runner.run_batch(ctx, tool_calls)

      -- Se houver cancelamento, interrompe o loop ReAct atómicamente de forma limpa
      if ctx.tool_cancelled then
        ctx.tool_cancelled = nil
        ctx.prev_command_cancelled = true
        return resp, elapsed, false, false, stream_complete, last_reasoning
      end

      iter     = iter + 1
      cur_text = nil
      cur_role = nil
      last_reasoning = ""
      if resp:match("%[FLUSH_DONE%]") then
        return resp, elapsed, true, false, stream_complete, ""
      end

    -- ── Caminho legado XML (fallback) ───────────────────────────────────
    else
      local texto, ferramentas, pre_feedback = th.parsear(resp)
      local display_text     = strip_flush_tag(texto)
      local has_pre_feedback = pre_feedback and pre_feedback ~= ""
      if #ferramentas > 0 or has_pre_feedback then
        if display_text ~= "" then ui.ai_msg_stream(display_text) end
        local exec_result = ""
        if #ferramentas > 0 then
          exec_result = th.executar(ferramentas)
          iter = iter + 1
        end
        cur_text = has_pre_feedback
          and (exec_result .. (exec_result ~= "" and "\n\n" or "") .. pre_feedback)
          or exec_result
        cur_role = "user"
        last_reasoning = ""
        if resp:match("%[FLUSH_DONE%]") then
          return resp, elapsed, true, false, stream_complete, ""
        end
      else
        local is_vazio = (display_text == "" or display_text == "[vazio]")
                         and not resp:match("^%[ERRO")
                         and not resp:match("%[FLUSH_DONE%]")
        local is_unfulfilled = not is_vazio
                            and is_unfulfilled_intent(display_text)
                            and not resp:match("^%[ERRO")
                            and not resp:match("%[FLUSH_DONE%]")
        if (is_vazio or is_unfulfilled) and vazio_count < MAX_VAZIO_RETRIES then
          vazio_count = vazio_count + 1
          if is_unfulfilled then
            ui.ai_msg_stream(display_text)
            cur_text = "[SISTEMA] Você anunciou uma ação mas não chamou "
                     .. "nenhuma ferramenta. Prossiga executando agora o "
                     .. "que foi anunciado."
          else
            cur_text = (reasoning and reasoning ~= "")
              and "[SISTEMA] Você estava processando mas não emitiu resposta. "
               .. "Revise o raciocínio anterior e entregue a resposta completa."
              or  "[SISTEMA] Continue de onde parou e revise o que estava fazendo."
          end
          cur_role = "user"
          local tag = is_unfulfilled and "anúncio sem execução" or "resposta vazia"
          io.write("\27[38;5;245m[auto-retry " .. vazio_count
            .. "/" .. MAX_VAZIO_RETRIES .. " " .. tag .. "]\27[0m\n")
          io.flush()
        else
          if is_vazio then
            io.write("\27[38;5;203m⚠️  Agente sem resposta após "
              .. MAX_VAZIO_RETRIES .. " tentativas automáticas.\27[0m\n\n")
            io.flush()
          elseif display_text ~= "" then
            ui.ai_msg_stream(display_text)
          end
          last_reasoning = reasoning or ""
          local flush_done = resp:match("%[FLUSH_DONE%]") ~= nil
          return resp, elapsed, flush_done, false, stream_complete, last_reasoning
        end
      end
    end
  end
  ui.agent_limit(limit)
  return "", elapsed, false, false, stream_complete, ""
end

return M
