-- agent/loop/tool_runner.lua — Executa um lote de tool_calls (Padrão Fachada).
local M = {}

local display  = require("agent.loop.tool_runner.display")
local executor = require("agent.loop.tool_runner.executor")

M.tc_preview = display.tc_preview
M.tc_display = display.tc_display
M.run_batch  = executor.run_batch

return M
