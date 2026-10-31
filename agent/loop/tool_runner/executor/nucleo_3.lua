-- agent/loop/tool_runner/executor/nucleo_3.lua — helpers internos: executar_grupo_read.
local resultado = require("lib.result")

return function(M)
  local P = require("agent.loop.tool_runner.executor.nucleo_2")(M)
  local ui, tools_mod, display, tracker, suffix, get_wall_time = P.ui, P.tools_mod, P.display, P.tracker, P.suffix, P.get_wall_time


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

      local ok = resultado.sucesso(result)
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
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.executar_grupo_read = executar_grupo_read
  return N
end
