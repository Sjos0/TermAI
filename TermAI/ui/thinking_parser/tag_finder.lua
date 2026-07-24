local M = {}

function M.find_first(s, tag)
  local p = s:find(tag, 1, true)
  if not p then return nil, nil end
  return p, p + #tag - 1
end

function M.find_any(s, tags)
  local bp, be, bt = nil, nil, nil
  for _, tag in ipairs(tags) do
    local p, e = M.find_first(s, tag)
    if p and (not bp or p < bp) then bp, be, bt = p, e, tag end
  end
  return bp, be, bt
end

return M
