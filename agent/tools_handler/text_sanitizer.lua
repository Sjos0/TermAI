-- agent/tools_handler/text_sanitizer.lua
-- Protecao de blocos de codigo para evitar falsos positivos no parser.
-- FIX Bug #08, FIX Bug #20. Sem dependencias externas.
local M = {}

-- FIX Bug #08: remove tags XML soltas preservando backticks inline.
local function strip_orphan_tags(texto)
  local parts = {}
  local in_code = false
  for line in (texto .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^%s*```") then in_code = not in_code end
    if not in_code then
      local saved = {}
      line = line:gsub("`([^`]*)`", function(c)
        saved[#saved+1] = c; return "\0" .. #saved .. "\0"
      end)
      line = line:gsub("<tool_call>%s*",  "")
                 :gsub("</tool_call>%s*", "")
                 :gsub("</function>%s*",  "")
                 :gsub("<tool>%s*",       "")
                 :gsub("</tool>%s*",      "")
                 :gsub("<name>%s*",       "")
                 :gsub("</name>%s*",      "")
                 :gsub("<arg>%s*",        "")
                 :gsub("</arg>%s*",       "")
      if #saved > 0 then
        line = line:gsub("\0(%d+)\0", function(n)
          return "`" .. saved[tonumber(n)] .. "`"
        end)
      end
    end
    parts[#parts + 1] = line
  end
  return table.concat(parts, "\n")
end

-- FIX Bug #20: substitui conteudo de code fences e backticks inline
-- por null bytes, mantendo paridade de bytes para preservar offsets.
local function neutralize_code_fences(text)
  local parts = {}
  local in_fence = false
  for line in (text.."\n"):gmatch("([^\n]*)\n") do
    if line:match("^%s*```") then
      in_fence = not in_fence
      parts[#parts+1] = string.rep("\0", #line)
    elseif in_fence then
      parts[#parts+1] = string.rep("\0", #line)
    else
      local safe_line = line:gsub("`([^`]*)`", function(m)
        return "`" .. string.rep("\0", #m) .. "`"
      end)
      parts[#parts+1] = safe_line
    end
  end
  return table.concat(parts, "\n")
end

M.strip_orphan_tags      = strip_orphan_tags
M.neutralize_code_fences = neutralize_code_fences

return M
