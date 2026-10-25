-- agent/loop/tool_runner/executor.lua — Orquestração de execuções individuais e em lote.
-- v2: PreToolUse ANTES de tool_start — evita bolinha amarela órfã após diálogo de permissão.
-- v2.1: propaga ctx.disabled_tools a call_structured (Issue #32 / Caçador #49).

local M = {}

local N = require("agent.loop.tool_runner.executor.nucleo_3")(M)
require("agent.loop.tool_runner.executor.parte_1")(M, N)

return M
