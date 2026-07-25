-- buffer.lua — Funções utilitárias para manipulação do buffer do thinking_parser.
local M = {}

-- Checks if a string `s` is a prefix of any tag in `tags`.
function M.is_prefix_of_any(s, tags)
  for _, tag in ipairs(tags) do
    if tag:sub(1, #s) == s then return true end
  end
  return false
end

-- Safely releases the buffer content, returning the index until which we can release.
-- Optimization (Bolt): Limits the backward scan to the maximum length of any tag in `watch`.
-- This avoids O(N^2) string allocations for long buffers, converting it to O(L_max) where L_max is tiny.
function M.safe_release(buf, watch)
  local max_len = 0
  for _, tag in ipairs(watch) do
    if #tag > max_len then max_len = #tag end
  end

  local len = #buf
  local start_i = math.max(1, len - max_len + 1)
  for i = len, start_i, -1 do
    if M.is_prefix_of_any(buf:sub(i), watch) then return i - 1 end
  end
  return len
end

return M
