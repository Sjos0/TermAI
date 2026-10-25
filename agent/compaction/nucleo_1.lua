-- agent/compaction/nucleo_1.lua — helpers internos: sanitize_roles.
return function(M)
  local P = require("agent.compaction.nucleo")(M)


  local function sanitize_roles(msgs)
    local clean = {}
    for _, m in ipairs(msgs) do
      if #clean == 0 then
        clean[#clean + 1] = { role = m.role, content = m.content, tool_calls = m.tool_calls, tool_call_id = m.tool_call_id, reasoning = m.reasoning, pasted_texts = m.pasted_texts }
      else
        local last = clean[#clean]
        if last.role == m.role and not last.tool_calls and not m.tool_calls then
          last.content = last.content .. "\n\n" .. (m.content or "")
        else
          clean[#clean + 1] = { role = m.role, content = m.content, tool_calls = m.tool_calls, tool_call_id = m.tool_call_id, reasoning = m.reasoning, pasted_texts = m.pasted_texts }
        end
      end
    end
    return clean
  end
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.sanitize_roles = sanitize_roles
  return N
end
