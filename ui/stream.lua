-- stream.lua — Fachada + API pública de streaming do reasoning do modelo.
-- Interface pública: M.stream_start, M.stream_reasoning, M.stream_token, M.stream_end
local N = require("ui.stream.nucleo")
local M = {}

function M.set_sink(custom) N.ESTADO.sink = custom end
function M.get_sink() return N.ESTADO.sink end

require("ui.stream.fluxo_raciocinio")(M, N)
require("ui.stream.fluxo")(M, N)

return M
