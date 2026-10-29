-- ui/spinner.lua — Fachada do spinner/thinking da TUI.
-- Interface pública inalterada: start_thinking, kill_spinner, mark_reasoning_started, etc.
local launch  = require("ui.spinner.launch")
local compact = require("ui.spinner.compact")
local retry   = require("ui.spinner.retry")

local M = {}

M.kill_spinner                  = launch.kill_spinner
M.cleanup_turno                 = launch.cleanup_turno
M.cleanup_startup               = launch.cleanup_startup
M.start_thinking                = compact.start_thinking
M.update_label                  = compact.update_label
M.is_running                    = compact.is_running
M.begin_request_region          = compact.begin_request_region
M.end_request_region            = compact.end_request_region
M.finish_reasoning_region       = compact.finish_reasoning_region
M.mark_reasoning_started        = compact.mark_reasoning_started
M.restart_spinner               = compact.restart_spinner
M.stop_thinking_and_print_compact = compact.stop_thinking_and_print_compact
M.stop_thinking                 = compact.stop_thinking
M.show_retry                    = retry.show_retry
M.clear_retry_lines             = retry.clear_retry_lines
M.show_api_error                = retry.show_api_error

return M
