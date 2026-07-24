local M = {}

function M.is_prefix_of_any(s, tags)
  for _, tag in ipairs(tags) do
    if tag:sub(1, #s) == s then return true end
  end
  return false
end

function M.safe_release(buf, watch)
  for i = #buf, 1, -1 do
    if M.is_prefix_of_any(buf:sub(i), watch) then return i - 1 end
  end
  return #buf
end

return M
