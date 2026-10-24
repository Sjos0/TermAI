-- tools/subagents/send_def.lua — Tools subagents_send e subagents_steer (lote 2 da paridade OpenClaw).
local control = require("tools.subagents.control")
local M = {}

function M.register(tools, get_ctx)
  tools.register("subagents_send",
    "Send a message to a running subagent you started. The subagent reads it at its next safe point, between model turns. Use it to add information or answer a question the subagent asked. Do not use it to change the subagent's goal; use subagents_steer for that. Do not use it on finished subagents; they cannot receive messages. Example: runId 'sub-6ada492f349e' with message 'Use the 2025 numbers only.'",
    function(arg)
      return control.enviar(arg, get_ctx(), "message")
    end,
    { type = "object", properties = { runId = { type = "string" }, message = { type = "string" } }, required = { "runId", "message" } })

  tools.register("subagents_steer",
    "Redirect a running subagent you started. The subagent receives the new direction at its next safe point and should change course from there. Use it when the subagent is working on the wrong thing and must switch focus. Do not use it to add facts; use subagents_send for that. Do not use it on finished subagents. Example: runId 'sub-6ada492f349e' with message 'Stop the benchmark and check the parser instead.'",
    function(arg)
      return control.enviar(arg, get_ctx(), "redirect")
    end,
    { type = "object", properties = { runId = { type = "string" }, message = { type = "string" } }, required = { "runId", "message" } })
end

return M
