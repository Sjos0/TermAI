-- agent/flush/gate_detector.lua — FPM GateDetector: inspeciona tool_calls e atualiza flush_state.
local M = {}

--- Detecta gates do protocolo baseado em tool_calls e resposta.
-- Atualiza flush_state in-place (exec, read, edit, done).
-- @param tool_calls table|nil Lista de tool_calls da API
-- @param resp string|nil Texto da resposta do modelo
-- @param flush_state table Estado mutável {exec, read, edit, done}
-- @param tool_results table|nil Resultados opcionais por índice (para gate edit)
function M.detect_gates(tool_calls, resp, flush_state, tool_results)
  tool_results = tool_results or {}
  if tool_calls and #tool_calls > 0 then
    for i, tc in ipairs(tool_calls) do
      local func = tc["function"] or tc
      local name = func.name or tc.name
      local args = func.arguments or tc.arguments or ""
      local args_str = type(args) == "string" and args or (type(args) == "table" and (args.file or args.path or "") or "")

      if not flush_state.exec then
        if name == "Exec" and (args_str:match("date") or args_str:match("%%Y") or args_str:match("%%A")) then
          flush_state.exec = true
        end
      end

      if not flush_state.read then
        if name == "Read" and (args_str:match("memory/") or args_str:match("%.md")) then
          flush_state.read = true
        end
      end

      if not flush_state.edit then
        if (name == "Edit" or name == "Write") and (args_str:match("memory/") or args_str:match("%.md")) then
          local result = tool_results[i]
          if result == nil or result == true or (type(result) == "string" and result:match("Sucesso")) then
            flush_state.edit = true
          end
        end
      end
    end
  end
  if not flush_state.done and resp and resp:match("%[FLUSH_DONE%]") then
    flush_state.done = true
  end
end

return M
