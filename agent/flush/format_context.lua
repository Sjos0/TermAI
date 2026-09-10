-- agent/flush/format_context.lua — Formata mensagens novas como bloco legível para o Memory Flush.
-- Remove XML de tools para evitar o "Mimicry Bug" (modelo imita histórico de tool calls).
local M = {}

--- Formata as mensagens novas como um bloco de texto legível.
-- @param msgs table Lista de mensagens {role, content}
-- @return string Contexto formatado para o prompt do flush
function M.format_context(msgs)
  if #msgs == 0 then
    return "[Nenhuma mensagem nova desde o último Flush]"
  end
  local parts = {}
  for _, m in ipairs(msgs) do
    if m.role == "user" or m.role == "assistant" then
      local role    = m.role == "user" and "USUÁRIO" or "AGENTE"
      local content = m.content or ""

      -- Removemos completamente as tool calls e resultados.
      -- Deixar "marcas falsas" confunde o modelo durante a extração de memória.
      content = content:gsub("<tool>.-</tool>", "")
      content = content:gsub("<tool_result[^>]*>.-</tool_result>", "")

      -- Trunca mensagens gigantescas para o flush context não explodir em tokens
      if #content > 1500 then
        content = content:sub(1, 1500) .. "\n… [truncado]"
      end
      if content:match("^%s*$") then goto continue end
      parts[#parts + 1] = "[" .. role .. "]\n" .. content
      ::continue::
    end
  end
  return #parts > 0
    and table.concat(parts, "\n\n" .. string.rep("─", 30) .. "\n\n")
    or  "[Contexto sem mensagens relevantes]"
end

return M
