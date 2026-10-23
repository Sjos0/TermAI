-- agent/loop/tool_runner/executor.lua — Orquestração de execuções individuais e em lote.
-- v2: PreToolUse ANTES de tool_start — evita bolinha amarela órfã após diálogo de permissão.
-- v2.1: propaga ctx.disabled_tools a call_structured (Issue #32 / Caçador #49).
local ui        = require("ui")
local tools_mod = require("tools")
local json      = require("json")
local display   = require("agent.loop.tool_runner.display")
local tracker   = require("agent.loop.tool_runner.tracker")
local suffix    = require("agent.loop.tool_runner.suffix")

local M = {}

local subagent_ui = require("ui.subagent")

-- Clone não desenha corpo de ferramenta: manda o nome para o bloco aninhado.
local function ui_start(ctx, disp)
  if ctx and ctx.is_subagent then
    if ctx.run_id then require("tools.subagents.events").append(ctx.run_id, "tool", disp) end
    return subagent_ui.child_start(disp)
  end
  return ui.tool_start(disp)
end

local function ui_end(ctx, disp, out, ok)
  if ctx and ctx.is_subagent then return subagent_ui.child_end() end
  return ui.tool_end(disp, out, ok)
end

local function get_wall_time()
  local f = io.open("/proc/uptime", "r")
  if not f then return os.time() end
  local val = f:read("*n")
  f:close()
  return val or os.time()
end

local function is_read_call(tc)
  return tc.name == "Read" and tools_mod.registry[tc.name] ~= nil
end


local function executar_individual(ctx, tc)
  local result
  if not tc.name or tc.name == "" or not tools_mod.registry[tc.name] then
    local bad  = tostring(tc.name or "")
    local disp = "(inválida: '" .. bad .. "')"
    ui_start(ctx, disp)
    local avail = {}
    for n in pairs(tools_mod.registry) do avail[#avail + 1] = n end
    table.sort(avail)
    result = "❌ Ferramenta '" .. bad .. "' não existe. Disponíveis: "
           .. table.concat(avail, ", ")
    ui_end(ctx, disp, result, false)
  else
    local json_ok, args_str = pcall(json.encode, tc.args or {})
    local tc_sig = tc.name .. ":" .. (json_ok and args_str or "")

    if ctx.last_tool_sig == tc_sig and (tc.name == "Write" or tc.name == "Edit") then
      local display_str = display.tc_display(tc) .. " [REDUNDANTE]"
      ui_start(ctx, display_str)
      result = "⚠️ [Harness] Bloqueio de redundância: Esta mesma chamada de ferramenta (" .. tc.name
             .. ") com os mesmos argumentos exatos já foi executada na iteração anterior. "
             .. "Se você precisa verificar o resultado ou realizar outro ajuste, prossiga de outra forma."
      ui_end(ctx, display_str, result, false)
    else
      ctx.last_tool_sig = tc_sig
      local display_str = display.tc_display(tc)

      -- PreToolUse ANTES de tool_start: evita bolinha amarela órfã
      local hooks_engine = require("agent.hooks.engine")
      local arg_str = tools_mod.format_arg_str(tc.name, tc.args)
      local allowed, reason = hooks_engine.run("PreToolUse", tc.name, arg_str)

      if not allowed then
        ui_start(ctx, display_str)
        result = "❌ [PERMISSÃO NEGADA] " .. (reason or "Ferramenta bloqueada.")
        ui_end(ctx, display_str, result, false)
        ctx.msgs[#ctx.msgs + 1] = {
          role         = "tool",
          tool_call_id = tc.id,
          content      = result .. suffix.build_system_suffix(ctx, nil, "CANCELLED"),
        }
        if reason and reason:find("negada pelo usuário") then
          ctx.tool_cancelled = true
        end
        return
      end

      ui_start(ctx, display_str)

      local start_t = get_wall_time()
      -- Issue #32 / #49: defesa em profundidade — schema já filtra, mas se
      -- tool_call desativada chegar (alucinação / histórico), recusar aqui.
      result = tools_mod.call_structured(tc.name, tc.args, {
        skip_pretool = true,
        disabled_tools = ctx.disabled_tools,
      })
      local elapsed_ms = math.max(0, math.floor((get_wall_time() - start_t) * 1000))

      local bp = require("agent.hooks.bash_patterns")
      local perms = require("agent.hooks.permissions")
      local last_app = bp.last_approval_type or perms.last_approval_type or "AUTO_APPROVED"

      bp.last_approval_type, perms.last_approval_type = nil, nil

      if last_app == "CANCELLED" then
        ctx.tool_cancelled = true
        result = "❌ Action cancelled by user."
      end

      local success = not result:match("^❌")
      ui_end(ctx, display_str, result, success)

      if not ctx.tool_cancelled then
        tracker.track_file(ctx, tc.name, tc.args, success)
      end

      ctx.msgs[#ctx.msgs + 1] = {
        role         = "tool",
        tool_call_id = tc.id,
        content      = result .. suffix.build_system_suffix(ctx, elapsed_ms, last_app),
      }
      return
    end
  end

  ctx.msgs[#ctx.msgs + 1] = {
    role         = "tool",
    tool_call_id = tc.id,
    content      = result .. suffix.build_system_suffix(ctx, nil, nil),
  }
end

local function executar_grupo_read(ctx, tcs)
  -- Contrato (issue #51, veredito do Arquiteto): PreToolUse ANTES da UI de grupo, igual ao
  -- caminho individual. Negada não executa; o resto do lote segue.
  local hooks_engine = require("agent.hooks.engine")
  local denied = {}
  for i, tc in ipairs(tcs) do
    local allowed, reason = hooks_engine.run("PreToolUse", tc.name, tools_mod.format_arg_str(tc.name, tc.args))
    if not allowed then denied[i] = reason or "Ferramenta bloqueada." end
  end
  ui.tool_group_read_start(#tcs)
  local names, oks = {}, {}
  for i, tc in ipairs(tcs) do
    local start_t = get_wall_time()
    local result
    if denied[i] then
      result = "❌ [PERMISSÃO NEGADA] " .. denied[i]
      if denied[i]:find("negada pelo usuário") then ctx.tool_cancelled = true end
    else
      -- skip_pretool: o PreToolUse já rodou acima; não rodar de novo. Filtro de desativação mantido (#32/#49).
      result = tools_mod.call_structured(tc.name, tc.args, {
        skip_pretool = true,
        disabled_tools = ctx.disabled_tools,
      })
    end
    local elapsed_ms = math.max(0, math.floor((get_wall_time() - start_t) * 1000))

    local bp = require("agent.hooks.bash_patterns")
    local perms = require("agent.hooks.permissions")
    local last_app = bp.last_approval_type or perms.last_approval_type or "AUTO_APPROVED"

    bp.last_approval_type, perms.last_approval_type = nil, nil

    if last_app == "CANCELLED" then
      ctx.tool_cancelled = true
      result = "❌ Action cancelled by user."
    end

    local ok = not result:match("^❌")
    names[#names + 1], oks[#oks + 1] = display.tc_preview(tc), ok

    if not ctx.tool_cancelled then
      tracker.track_file(ctx, tc.name, tc.args, ok)
    end

    ctx.msgs[#ctx.msgs + 1] = {
      role         = "tool",
      tool_call_id = tc.id,
      content      = result .. suffix.build_system_suffix(ctx, elapsed_ms, last_app),
    }

    if ctx.tool_cancelled then break end
  end
  ui.tool_group_read_end(names, oks)
end

function M.run_batch(ctx, tool_calls)
  local i, n = 1, #tool_calls
  while i <= n do
    local tc      = tool_calls[i]
    local run_len = 1
    if is_read_call(tc) and not ctx.is_subagent then
      local j = i
      while j <= n and is_read_call(tool_calls[j]) do j = j + 1 end
      run_len = j - i
    end
    if run_len >= 2 then
      local group = {}
      for k = i, i + run_len - 1 do group[#group + 1] = tool_calls[k] end
      executar_grupo_read(ctx, group)
      if ctx.tool_cancelled then break end
      i = i + run_len
    else
      executar_individual(ctx, tc)
      if ctx.tool_cancelled then break end
      i = i + 1
    end
  end
end

return M
