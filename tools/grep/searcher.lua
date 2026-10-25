
local M = {}

local N = require("tools.grep.searcher.nucleo_1")(M)
require("tools.grep.searcher.parte_1")(M, N)

return M
