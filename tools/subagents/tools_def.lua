-- tools/subagents/tools_def.lua — Schemas e registro das tools de subagentes.
local spawn   = require("tools.subagents.spawn")
local control = require("tools.subagents.control")
local M = {}

function M.register(tools, get_parent)
  tools.register("sessions_spawn",
    [==[Start a background subagent and return its runId immediately. Without agentId the subagent is a clone of this agent; with agentId it runs that independent agent. Use it for independent work that can run in parallel, such as research or a long build. Do not use it for a quick answer you can produce yourself. A subagent cannot start another subagent unless maxSpawnDepth is raised in the config. Do not poll: in the TUI the result arrives automatically as a system message, and outside the TUI you should call subagents_wait. Limits: 5 running at once in total and 5 per parent agent. The default timeout is 600 seconds. Example: task 'Survey the session/ folder and summarize each module'.]==],
    function(arg)
      return spawn.spawn(type(arg) == "table" and arg or { task = tostring(arg or "") }, get_parent())
    end,
    { type = "object", properties = {
        task = { type = "string", description = "Task for the subagent. Required." },
        agentId = { type = "string", description = "Existing independent agent to run. Omit it to clone this agent." },
        label = { type = "string", description = "Short label shown in listings." },
        model = { type = "string", description = "Model as provider/id. Optional." },
        cleanup = { type = "string", description = "retain (default: kept for 7 days or 50 runs), delete (removed right after the result is delivered), or keep (no limit)." },
        runTimeoutSeconds = { type = "number", description = "Maximum run time in seconds (default 600)." },
      }, required = { "task" } })

  tools.register("subagents_list", [==[List the subagents and their statuses. Use it to see what is running or finished before inspecting one with subagents_info. Takes an optional status filter, for example 'running' or 'completed'. Takes no required arguments. Do not use it to stop subagents; use subagents_kill for that.]==],
    function(arg) return control.listar(type(arg) == "table" and arg or {}) end,
    { type = "object", properties = { status = { type = "string" } } })

  tools.register("subagents_info", [==[Show the details card of one subagent: status, timestamps, duration, token usage, delivery state, cleanup policy, error class and a redacted result preview. Use it after subagents_list, or when a result message mentions a runId. The runId is required. An unknown id returns status unknown. Do not use it to wait for a result; use subagents_wait for that. Example: runId 'sub-6ada492f349e'.]==],
    function(arg) return control.info(type(arg) == "table" and arg or { runId = tostring(arg or "") }) end,
    { type = "object", properties = { runId = { type = "string" } }, required = { "runId" } })

  tools.register("subagents_log", [==[Show the most recent events of one subagent, such as tool calls and retries (20 lines by default). Use it to diagnose a subagent that is slow or has failed. Do not use it to read the result; use subagents_info for that. The runId is required. The optional 'linhas' parameter sets how many lines to return.]==],
    function(arg) return control.log(type(arg) == "table" and arg or { runId = tostring(arg or "") }) end,
    { type = "object", properties = { runId = { type = "string" }, linhas = { type = "number" } },
      required = { "runId" } })

  tools.register("subagents_wait", [==[Wait for one subagent to finish, up to timeoutSeconds (maximum 300), and return its result. Use it only when the automatic result message cannot arrive, for example in headless execution. If the timeout expires, it returns the current progress; call it again to keep waiting. Do not poll subagents_info in a loop. Example: runId 'sub-6ada492f349e' with timeoutSeconds 120.]==],
    function(arg) return control.esperar(type(arg) == "table" and arg or { runId = tostring(arg or "") }) end,
    { type = "object", properties = { runId = { type = "string" }, timeoutSeconds = { type = "number" } }, required = { "runId" } })

  tools.register("subagents_kill", [==[Stop a running subagent and every subagent it started. Use it only when the work is no longer needed or is stuck. The runId is required. Finished subagents are not affected. This action needs the user's approval, and stopped work cannot be resumed. Do not use it to clean up finished subagents; they are removed automatically under the retention policy.]==],
    function(arg) return control.matar(type(arg) == "table" and arg or { runId = tostring(arg or "") }) end,
    { type = "object", properties = { runId = { type = "string" } }, required = { "runId" } })
end

return M
