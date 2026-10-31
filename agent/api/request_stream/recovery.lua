-- agent/api/request_stream/recovery.lua — remove só tool_calls órfãos (#270, #279).
local M = {}

local function has_tool_reply(msgs, start_i, tc_id)
  for j = start_i + 1, #msgs do
    local m = msgs[j]
    if m.role == "tool" and (not tc_id or m.tool_call_id == tc_id) then
      return true
    end
    -- outra mensagem de user/assistant interrompe a sequência deste tool_call
    if m.role == "user" or m.role == "assistant" then
      return false
    end
  end
  return false
end

--- Remove apenas assistant com tool_calls sem tool correspondente (e tools órfãs).
--- Não apaga mensagens posteriores de user/assistant válidas.
--- Retorna "[recover] …" se removeu algo; nil caso contrário.
function M.recover_tool_seq(msgs)
  if not msgs or #msgs == 0 then return nil end
  local removed_names = {}
  local i = 1
  while i <= #msgs do
    local m = msgs[i]
    if m.role == "assistant" and m.tool_calls and #m.tool_calls > 0 then
      local orphan = false
      local names = {}
      for _, tc in ipairs(m.tool_calls) do
        names[#names + 1] = (tc["function"] or {}).name or "?"
        local id = tc.id
        if not has_tool_reply(msgs, i, id) then
          orphan = true
        end
      end
      if orphan then
        for _, n in ipairs(names) do removed_names[#removed_names + 1] = n end
        -- remove o assistant órfão
        table.remove(msgs, i)
        -- remove tools imediatamente seguintes que pertenciam a ele
        while i <= #msgs and msgs[i].role == "tool" do
          table.remove(msgs, i)
        end
        -- não incrementa i: próximo elemento já está em i
      else
        i = i + 1
      end
    else
      i = i + 1
    end
  end
  if #removed_names == 0 then return nil end
  return "[recover] sequência removida: " .. table.concat(removed_names, ", ")
end

return M
