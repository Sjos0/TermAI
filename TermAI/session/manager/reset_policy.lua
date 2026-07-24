-- reset_policy.lua — Determina se uma sessão precisa ser resetada.
local state      = require("session.manager.state")
local date_utils = require("session.manager.date_utils")
local M = {}

local function needs_daily_reset(s)
  local rc         = state._config.reset or {}
  if not rc.daily then return false end
  local reset_hour = rc.daily_hour or 4
  local last       = s.last_activity or s.updated_at or s.created_at or ""
  local last_time  = date_utils.parse_iso(last)
  if not last_time then return false end
  local now = os.time()
  local nd  = os.date("*t", now)
  local boundary = os.time({
    year = nd.year, month = nd.month, day = nd.day,
    hour = reset_hour, min = 0, sec = 0,
  })
  if now < boundary then boundary = boundary - 86400 end
  return last_time < boundary
end

local function needs_idle_reset(s)
  local rc   = state._config.reset or {}
  local idle = rc.idle_minutes
  if not idle or idle <= 0 then return false end
  local last      = s.last_activity or s.updated_at or ""
  local last_time = date_utils.parse_iso(last)
  if not last_time then return false end
  return (os.time() - last_time) > (idle * 60)
end

M.needs_daily_reset = needs_daily_reset
M.needs_idle_reset  = needs_idle_reset
return M
