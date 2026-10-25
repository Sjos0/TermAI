-- tests/loop_units_spec/dobles.lua — Dublês compartilhados pelas partes do spec de agent/loop.
-- Instala os stubs de ui, do tool_runner, do tools_handler e da memória UMA vez (ao ser
-- carregado) e guarda o estado que as partes leem e zeram: logs de UI e de batch, estados
-- de parse e de memória. Ver tests/loop_units_spec.lua.
local M = {}

-- ═══════════════════════════════════════════════════════════════
-- Doubles compartilhados
-- ═══════════════════════════════════════════════════════════════
M.ui_log = {}
function M.reset_ui_log() M.ui_log = {} end
package.loaded["ui"] = {
  start_thinking = function(label)
    M.ui_log[#M.ui_log + 1] = { op = "start_thinking", label = label }
  end,
  update_label = function()
    M.ui_log[#M.ui_log + 1] = { op = "update_label" }
  end,
  ai_msg_stream = function(text)
    M.ui_log[#M.ui_log + 1] = { op = "ai_msg_stream", text = text }
  end,
  agent_limit = function() end,
  stop_thinking = function() return 0.1 end,
}

M.batch_log = {}
package.loaded["agent.loop.tool_runner"] = {
  run_batch = function(ctx, tool_calls)
    M.batch_log[#M.batch_log + 1] = { ctx = ctx, tool_calls = tool_calls }
  end,
}

M.th_state = {
  texto = "",
  ferramentas = {},
  pre_feedback = nil,
  exec_result = "",
}
package.loaded["agent.tools_handler"] = {
  parsear = function(resp)
    return M.th_state.texto, M.th_state.ferramentas, M.th_state.pre_feedback
  end,
  executar = function(ferramentas)
    return M.th_state.exec_result
  end,
}

M.mem_state = {
  available = false,
  result = nil,
  should_error = false,
}
package.preload["tools.memory"] = function()
  if not M.mem_state.available then
    error("memory not available")
  end
  return {
    search = function(q)
      if M.mem_state.should_error then error("search failed") end
      return M.mem_state.result
    end,
  }
end

-- Define o que o parser de resposta devolve nas próximas chamadas (xml_path).
function M.set_th(texto, ferramentas, pre_feedback, exec_result)
  M.th_state.texto = texto or ""
  M.th_state.ferramentas = ferramentas or {}
  M.th_state.pre_feedback = pre_feedback
  M.th_state.exec_result = exec_result or ""
end

return M
