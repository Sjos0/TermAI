local M = {}

function M.sanitize_message(value)
  local line = tostring(value or ""):gsub("[\r\n]+", " ")
  line = line:gsub("\27%[[0-?]*[ -/]*[@-~]", "")
  line = line:gsub("\27%].-\7", ""):gsub("\27%].-\27\\", "")
  line = line:gsub("\27[PX^_].-\27\\", ""):gsub("\27.", "")
  return line:gsub("[%z\1-\31\127]", " ")
end

function M.error_message(value, secret)
  local line = M.sanitize_message(value)
  if type(secret) == "string" and secret ~= "" then
    line = line:gsub(secret:gsub("([^%w])", "%%%1"), "[REDACTED]")
  end
  return line
end

function M.label(item)
  if not item then return "  [sem teste]" end
  local value = item.last_error_at or item.last_ok
  if not value then return "  [sem teste]" end
  local year, month, day, hour, minute = tostring(value):match(
    "^(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):%d%dZ$")
  if year then
    value = string.format("%s/%s/%s %s:%s UTC", day, month, year, hour, minute)
  end
  local kind = item.last_error_at and "última falha" or "último OK"
  return "  [" .. kind .. ": " .. tostring(value) .. "]"
end

return M
