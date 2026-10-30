-- agent/api/request_stream/recovery.lua — Recuperação agressiva de histórico quebrado (#270).
local M = {}

--- Remove tool_calls órfãos. Retorna texto "[recover] ..." ou nil (sem io.write).
function M.recover_tool_seq(msgs)
  for i = #msgs, 1, -1 do
    if msgs[i].role == "assistant" and msgs[i].tool_calls then
      local names = {}
      for _, tc in ipairs(msgs[i].tool_calls) do
        names[#names + 1] = (tc["function"] or {}).name or "?"
      end
      while #msgs >= i do table.remove(msgs) end
      return "[recover] sequência removida: " .. table.concat(names, ", ")
    end
  end
  return nil
end

return M
