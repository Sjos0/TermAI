-- agent/api/request_stream/recovery.lua — Recuperação agressiva de histórico quebrado.
local M = {}

function M.recover_tool_seq(msgs)
  for i = #msgs, 1, -1 do
    if msgs[i].role == "assistant" and msgs[i].tool_calls then
      local names = {}
      for _, tc in ipairs(msgs[i].tool_calls) do
        names[#names + 1] = (tc["function"] or {}).name or "?"
      end
      io.write("\27[38;5;203m[recover] sequência removida: "
        .. table.concat(names, ", ") .. "\27[0m\n")
      io.flush()
      while #msgs >= i do table.remove(msgs) end
      return true
    end
  end
  return false
end

return M
