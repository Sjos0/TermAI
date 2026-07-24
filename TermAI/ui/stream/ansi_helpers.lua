-- ansi_helpers.lua — Constantes ANSI, labels de header e animação de dots.
local core  = require("ui.core")
local state = require("ui.stream.state")
local c = core.c
local M = {}

local DARK_GREEN    = "\27[38;5;71m"
local DOTS_INTERVAL = 1

local function dots_str(n)
  return string.rep(".", n) .. string.rep(" ", 3 - n)
end

local function header_label(concluded, dots)
  if concluded then
    return c.dim .. c.gray .. " ╭─ Pensamento Concluído "
      .. DARK_GREEN .. "✓" .. "\27[K" .. c.reset
  end
  return c.dim .. c.gray .. " ╭─ Pensando"
    .. dots_str(dots or 1) .. "\27[K" .. c.reset
end

local function tick_dots()
  local now = os.time()
  if now - state._last_dots_time >= DOTS_INTERVAL then
    state._last_dots_time = now
    state._s.dots = ((state._s.dots or 1) % 3) + 1
    return true
  end
  return false
end

local function update_header_dots()
  local s = state._s
  local lines_up
  if s.phase == "collapsed" then
    lines_up = s.box_lines or 1
  else
    lines_up = s.reasoning_lines or 1
  end
  if lines_up <= 0 then return end
  io.write("\27[s")
  io.write(string.format("\27[%dA\r", lines_up))
  io.write("\27[K")
  io.write(header_label(false, s.dots))
  io.write("\27[u")
  io.flush()
end

M.DARK_GREEN         = DARK_GREEN
M.DOTS_INTERVAL      = DOTS_INTERVAL
M.dots_str           = dots_str
M.header_label       = header_label
M.tick_dots          = tick_dots
M.update_header_dots = update_header_dots
return M
