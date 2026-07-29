-- Fachada: reexporta a interface publica de ui.thinking_parser.
-- Consumidores (api.lua, loop.lua, flush.lua) continuam usando
--   require("ui.thinking_parser")
-- sem qualquer alteracao.
local state         = require("ui.thinking_parser.state")
local init          = require("ui.thinking_parser.init")
local depth_tracker = require("ui.thinking_parser.depth_tracker")

local M = {}

function M.reset()
  state.reset()
  depth_tracker.reset()
end

M.flush = state.flush
M.feed  = init.feed

return M
