-- tests/flush_tdd/gates_impl.lua — implementação de referência do detector de gates (TDD, usada por tests/flush_tdd_gates_spec.lua).
local M = {}

-- Função a ser implementada em flush.lua
-- tool_calls: array de tool calls do modelo
-- resp: texto da resposta do modelo
-- flush_state: tabela com 4 campos booleanos
-- tool_results: (opcional) tabela com resultados das tools
function M.detect_gates(tool_calls, resp, flush_state, tool_results)
  tool_results = tool_results or {}

  if tool_calls and #tool_calls > 0 then
    for i, tc in ipairs(tool_calls) do
      local func = tc["function"] or tc
      local name = func.name or tc.name
      local args = func.arguments or tc.arguments or ""
      local args_str = type(args) == "string" and args or (type(args) == "table" and (args.file or args.path or "") or "")

      -- Gate exec: date (nome de produção: "Exec")
      if not flush_state.exec then
        if name == "Exec" and (args_str:match("date") or args_str:match("%%Y") or args_str:match("%%A")) then
          flush_state.exec = true
        end
      end

      -- Gate read: memory/*.md
      if not flush_state.read then
        if name == "Read" and (args_str:match("memory/") or args_str:match("%.md")) then
          flush_state.read = true
        end
      end

      -- Gate edit: Edit/Write memory/*.md com sucesso
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

  -- Gate done: FLUSH_DONE na resposta
  if not flush_state.done and resp and resp:match("%[FLUSH_DONE%]") then
    flush_state.done = true
  end
end

-- ==========================================
-- TESTES
-- ==========================================
return M
