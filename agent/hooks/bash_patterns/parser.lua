-- agent/hooks/bash_patterns/parser.lua — Parsing de pipelines, subshells,
-- heredocs e curingas.
local M = {}

local N = require("agent.hooks.bash_patterns.parser.nucleo_1")(M)
require("agent.hooks.bash_patterns.parser.parte_1")(M, N)
require("agent.hooks.bash_patterns.parser.parte_2")(M, N)

return M
