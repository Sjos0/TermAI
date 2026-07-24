-- serialize.lua — Serializa mensagens descartadas para o prompt de resumo
-- da compactação. Extraído de compaction/init.lua (era função local
-- `serialize_messages`) pra manter a fachada fina.
--
-- IMPORTANTE: este é o serializador REAL usado por do_compaction. Não
-- confundir com agent/api/summarizer/serializer.lua — esse outro módulo
-- pertence ao pipeline `summarizer` que NUNCA é chamado no caminho de
-- compactação (confirmado: init.lua nunca dá require nele).
--
-- REQ-4: trunca role="tool" em TOOL_RESULT_MAX_CHARS pra não estourar o
-- orçamento do prompt de resumo com um único read de arquivo grande.
local json = require("json")
local M = {}

local TOOL_RESULT_MAX_CHARS <const> = 2000

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
          local args_str = type(args) == "table" and json.encode(args) or args
          block[#block+1] = string.format("  Ferramenta: %s | Argumentos: %s", name or "desconhecida", args_str or "")
        end
      end
    elseif msg.role == "tool" then
      block[#block+1] = "[RESULTADO DA FERRAMENTA]"
      local conteudo = msg.content or ""
      local tamanho_original = #conteudo
      if tamanho_original > TOOL_RESULT_MAX_CHARS then
        conteudo = conteudo:sub(1, TOOL_RESULT_MAX_CHARS)
          .. string.format("\n\n[... %d caracteres truncados]", tamanho_original - TOOL_RESULT_MAX_CHARS)
      end
      block[#block+1] = conteudo
    elseif msg.role == "system" then
      block[#block+1] = "[INSTRUÇÃO DO SISTEMA]"
      block[#block+1] = msg.content or ""
    end
    partes[#partes + 1] = table.concat(block, "\n")
  end
  return table.concat(partes, "\n\n")
end

return M
