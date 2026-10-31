-- agent/loop/tool_runner/executor/nucleo_2.lua — helpers internos: executar_individual.
local resultado = require("lib.result")

return function(M)
  local P = require("agent.loop.tool_runner.executor.nucleo_1")(M)
  local tools_mod, json, display, tracker, suffix, ui_start, ui_end, get_wall_time = P.tools_mod, P.json, P.display, P.tracker, P.suffix, P.ui_start, P.ui_end, P.get_wall_time



  local function executar_individual(ctx, tc)
    local result
    if not tc.name or tc.name == "" or not tools_mod.registry[tc.name] then
      local bad  = tostring(tc.name or "")
      local disp = "(inválida: '" .. bad .. "')"
      ui_start(ctx, disp)
      local avail = {}
      for n in pairs(tools_mod.registry) do avail[#avail + 1] = n end
      table.sort(avail)
      result = "[FAIL] Ferramenta '" .. bad .. "' não existe. Disponíveis: "
             .. table.concat(avail, ", ")
      ui_end(ctx, disp, result, false)
    else
      local json_ok, args_str = pcall(json.encode, tc.args or {})
      local tc_sig = tc.name .. ":" .. (json_ok and args_str or "")

      if ctx.last_tool_sig == tc_sig and (tc.name == "Write" or tc.name == "Edit") then
        local display_str = display.tc_display(tc) .. " [REDUNDANTE]"
        ui_start(ctx, display_str)
        result = "[WARN] [Harness] Bloqueio de redundância: Esta mesma chamada de ferramenta (" .. tc.name
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
          result = "[FAIL] [PERMISSÃO NEGADA] " .. (reason or "Ferramenta bloqueada.")
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
          result = "[FAIL] Action cancelled by user."
        end

        local success = resultado.sucesso(result)
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
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.executar_individual = executar_individual
  return N
end
