-- xml_cleaner.lua — Remove blocos de tool calls e tags órfãs do texto do histórico.
-- Dependências externas: nenhuma (Lua puro).
local M = {}

-- Remove blocos tool multi-linha e tags orfas do texto do historico.
-- Lua's . nao cruza \n: substituimos \n por \0 antes do gsub para
-- que o padrao possa cruzar linhas, depois restauramos.
local function strip_tool_xml(s)
  if not s then return "" end
  local flat = s:gsub("\n", "\0")
  flat = flat:gsub("<tool>.-</tool>",           "")
  flat = flat:gsub("<tool_call>.-</tool_call>", "")
  flat = flat:gsub("</?tool[_a-zA-Z]*>\0*",     "")
  flat = flat:gsub("</?name>\0*",               "")
  flat = flat:gsub("</?arg[a-z_]*>\0*",         "")
  flat = flat:gsub("</?arguments>\0*",          "")
  flat = flat:gsub("</function>\0*",            "")
  flat = flat:gsub("\0+",                       "\n")
  return flat:match("^%s*(.-)%s*$") or ""
end

M.strip_tool_xml = strip_tool_xml
return M
