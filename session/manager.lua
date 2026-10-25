-- session/manager.lua — Fachada + Orquestrador do sistema de sessões.
-- Interface pública inalterada: M.init, M.current, M.load_history,
-- M.save_message, M.save_compaction, M.set_model, M.new, M.reset,
-- M.list, M.switch, M.status, M.cleanup, M.get_flush_index, M.save_flush_index
local M = {}

local N = require("session.manager.nucleo")(M)
require("session.manager.parte_1")(M, N)
require("session.manager.parte_2")(M, N)

return M
