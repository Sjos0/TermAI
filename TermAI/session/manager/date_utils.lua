-- date_utils.lua — Conversão e manipulação de timestamps ISO.
local M = {}

local function now_iso()
  return os.date("%Y-%m-%dT%H:%M:%S")
end

local function parse_iso(s)
  if not s or s == "" then return nil end
  local y, m, d, h, mn, sc = s:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
  if not y then return nil end
  return os.time({
    year  = tonumber(y), month = tonumber(m), day = tonumber(d),
    hour  = tonumber(h), min   = tonumber(mn), sec = tonumber(sc),
  })
end

local function iso_to_timestamp(ts)
  if not ts or ts == "" then return nil end
  local d, t = ts:match("(%d%d%d%d%-%d%d%-%d%d)T(%d%d:%d%d:%d%d)")
  if not d then return nil end
  return d .. " " .. t
end

M.now_iso          = now_iso
M.parse_iso        = parse_iso
M.iso_to_timestamp = iso_to_timestamp
return M
