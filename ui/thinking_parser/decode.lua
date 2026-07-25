-- decode.lua — Decodificação de entidades HTML no stream parser.
local M = {}

-- Decodes HTML entities back to their original characters.
-- Optimization (Bolt): Added an early return check `not s:find("&", 1, true)`.
-- If no '&' is present in the token (which is true for 99.9% of LLM stream tokens),
-- we completely avoid three expensive `gsub` calls, achieving a massive speedup.
function M.decode_entities(s)
  if not s:find("&", 1, true) then
    return s
  end
  s = s:gsub("&lt;", "<")
  s = s:gsub("&gt;", ">")
  s = s:gsub("&amp;", "&")
  return s
end

return M
