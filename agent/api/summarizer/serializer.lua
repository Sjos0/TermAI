-- agent/api/summarizer/serializer.lua — Serialização estruturada de históricos de conversação e ferramentas.
local json = require("json")

local M = {}

-- Serializa mensagens descartadas de forma explícita, incluindo chamadas e retornos
function M.serialize_messages(mensagens)
  local partes = {}
  for _, msg in ipairs(mensagens) do
    local block = {}

    if msg.role == "user" then
      block[#block+1] = "[USUÁRIO]"
      block[#block+1] = msg.content or ""
    elseif msg.role == "assistant" then
      block[#block+1] = "[AGENTE]"
      if msg.content and msg.content ~= "" then
        block[#block+1] = msg.content
      end
      if msg.tool_calls and #msg.tool_calls > 0 then
        block[#block+1] = "--> CHAMADAS DE FERRAMENTA:"
        for _, tc in ipairs(msg.tool_calls) do
          local func = tc["function"] or tc
          local name = func.name
          local args = func.arguments or tc.args or tc.arguments
          local args_str = ""
          if type(args) == "table" then
            args_str = json.encode(args)
          elseif type(args) == "string" then
            args_str = args
          end
          block[#block+1] = string.format("  Ferramenta: %s | Argumentos: %s", name or "desconhecida", args_str)
        end
      end
    elseif msg.role == "tool" then
      block[#block+1] = "[RESULTADO DA FERRAMENTA]"
      block[#block+1] = msg.content or ""
    elseif msg.role == "system" then
      block[#block+1] = "[INSTRUÇÃO DO SISTEMA]"
      block[#block+1] = msg.content or ""
    end

    partes[#partes + 1] = table.concat(block, "\n")
  end
  return table.concat(partes, "\n\n")
end

return M
