-- Fachada: reexporta a interface publica de ui.thinking_parser.
-- Consumidores (api.lua, loop.lua, flush.lua) continuam usando
--   require("ui.thinking_parser")
-- sem qualquer alteracao.
local state = require("ui.thinking_parser.state")
local init  = require("ui.thinking_parser.init")

local M = {}

M.reset = state.reset
M.flush = state.flush
M.feed  = init.feed

return M
