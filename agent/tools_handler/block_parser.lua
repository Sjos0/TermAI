-- agent/tools_handler/block_parser.lua
-- Extracao de tool calls de blocos XML. Depende de xml_extractor e tools.
local xml   = require("agent.tools_handler.xml_extractor")
local tools = require("tools")
local M     = {}

local function parse_format(texto_para_analise, texto_limpo, ferramentas, seen,
                            open_tag, close_tag, invalid_tools)
  local blocks = xml.find_top_level_blocks(texto_para_analise, open_tag, close_tag)

  -- Itera de tras para frente para preservar offsets ao remover blocos.
  for i = #blocks, 1, -1 do
    local b = blocks[i]

    local tool_block_limpo = texto_limpo:sub(b.s, b.e)

    local nome = xml.extract_first(tool_block_limpo, "<name>", "</name>")
    local arg  = xml.extract_last(tool_block_limpo, "<arg>", "</arg>")
              or xml.extract_last(tool_block_limpo, "<arguments>", "</arguments>") or ""

    texto_limpo = texto_limpo:sub(1, b.s - 1) .. texto_limpo:sub(b.e + 1)

    if nome and nome ~= "" then
      if tools.registry[nome] then
        local sig = nome .. "||" .. arg
        if not seen[sig] then
          seen[sig] = true
          table.insert(ferramentas, 1, { nome = nome, arg = arg })
        end
      elseif invalid_tools then
        local sig = nome .. "||" .. arg
        if not seen[sig] then
          seen[sig] = true
          invalid_tools[#invalid_tools+1] = { nome = nome, arg = arg }
        end
      end
    end
  end
  return texto_limpo
end

M.parse_format = parse_format

return M
