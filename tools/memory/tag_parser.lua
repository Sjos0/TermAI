-- tag_parser.lua — Parser de tags [[Obsidian]] e extrator de snippets contextuais.
local M = {}

local function extract_tags(content)
  local tags = {}
  local seen  = {}
  for tag in content:gmatch("%[%[([^%]%[]+)%]%]") do
    local normalized = tag:lower():match("^%s*(.-)%s*$")
    if normalized ~= "" and not seen[normalized] then
      seen[normalized] = true
      tags[#tags + 1] = normalized
    end
  end
  return tags
end

local function get_snippet(content, tag, radius, lower_content)
  radius = radius or 250
  -- Escapa o tag para uso no padrão Lua
  local escaped = tag:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1")
  local pattern  = "%[%[" .. escaped .. "%]%]"
  local pos      = (lower_content or content:lower()):find(pattern)

  if not pos then
    -- fallback: primeiros N chars do arquivo
    local s = content:sub(1, radius)
    return (#content > radius) and (s .. "…") or s
  end

  local s_pos = math.max(1, pos - 120)
  local e_pos = math.min(#content, pos + radius)
  local snippet = content:sub(s_pos, e_pos)

  if s_pos > 1        then snippet = "…" .. snippet end
  if e_pos < #content then snippet = snippet .. "…" end
  return snippet
end

M.extract_tags = extract_tags
M.get_snippet  = get_snippet
return M
