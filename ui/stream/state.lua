-- state.lua — Estado compartilhado do ciclo de streaming.
-- Singleton via require() cache: todos os módulos leem/escrevem a mesma instância.
local M = {}

M._s              = {}
M._last_dots_time = 0

function M.reset()
  M._s = {
    full              = "",
    reasoning         = "",
    started           = false,
    reasoning_started = false,
    phase             = "idle",
    reasoning_lines   = 0,
    reasoning_col     = 0,
    reasoning_visible = nil,
    extra_lines       = 0,
    dots              = 1,
    box_lines         = 0,
  }
  M._last_dots_time = 0
end

return M
