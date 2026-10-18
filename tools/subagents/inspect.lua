-- tools/subagents/inspect.lua — listar, status, wait, cancel.
local json   = require("json")
local store  = require("tools.subagents.store")
local runner = require("tools.subagents.child_runner")
local M = {}

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function M.listar(args)
  args = type(args) == "table" and args or {}
  local filter = {}
  if args.status and args.status ~= "" then filter.status = args.status end
  if args.parent and args.parent ~= "" then filter.parent_agent_id = args.parent end
  if args.agentId and args.agentId ~= "" then filter.agentId = args.agentId end
  local runs = store.list(filter)
  if #runs == 0 then return "Nenhum child run encontrado." end
  local lines = { "Child runs (" .. #runs .. "):" }
  for _, r in ipairs(runs) do
    lines[#lines + 1] = string.format(
      "- %s | %s | agent=%s | parent=%s | %s",
      r.runId, r.status, tostring(r.agentId), tostring(r.parent_agent_id),
      r.label or (r.task and r.task:sub(1, 40)) or ""
    )
  end
  return table.concat(lines, "\n")
end

function M.status(args)
  args = type(args) == "table" and args or {}
  local run_id = args.runId or args.run_id
  if type(args) == "string" and args ~= "" then run_id = args end
  if not run_id or run_id == "" then
    return "❌ subagents_status: informe runId."
  end
  local r = store.get(run_id)
  if not r then return "❌ Run não encontrado: " .. tostring(run_id) end
  return json.encode({
    runId = r.runId,
    status = r.status,
    agentId = r.agentId,
    childSessionKey = r.childSessionKey,
    result_text = r.result_text,
    error = r.error,
    created_at = r.created_at,
    finished_at = r.finished_at,
    announce_pending = r.announce_pending,
  })
end

function M.wait(args, parent_ctx)
  args = type(args) == "table" and args or {}
  local run_id = args.runId or args.run_id
  if not run_id or run_id == "" then
    return "❌ subagents_wait: informe runId."
  end
  local r = store.get(run_id)
  if not r then return "❌ Run não encontrado: " .. tostring(run_id) end

  local deadline = os.time() + (tonumber(args.timeoutSeconds) or 120)
  while r.status == "queued" or r.status == "running" do
    if os.time() > deadline then
      return json.encode({
        runId = r.runId,
        status = r.status,
        partial = true,
        message = "timeout aguardando conclusão",
        result_text = r.result_text,
      })
    end
    if r.status == "queued" then
      runner.advance(r, parent_ctx and parent_ctx.cfg)
      r = store.get(run_id) or r
    else
      os.execute("sleep 0.2")
      r = store.get(run_id) or r
    end
  end

  return json.encode({
    runId = r.runId,
    status = r.status,
    result_text = r.result_text,
    error = r.error,
    finished_at = r.finished_at,
  })
end

function M.cancel(args)
  args = type(args) == "table" and args or {}
  local run_id = args.runId or args.run_id
  if not run_id or run_id == "" then
    return "❌ subagents_cancel: informe runId."
  end
  local r = store.get(run_id)
  if not r then return "❌ Run não encontrado: " .. tostring(run_id) end
  if r.status == "completed" or r.status == "failed" or r.status == "timeout" then
    return "Run já terminal: " .. r.status
  end
  r.status = "failed"
  r.error = "cancelled"
  r.finished_at = now_iso()
  r.updated_at = r.finished_at
  r.announce_pending = true
  store.upsert(r)
  return json.encode({ runId = r.runId, status = r.status, error = r.error })
end

return M
