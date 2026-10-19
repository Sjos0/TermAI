-- tools/subagents/scheduler.lua — Avança children em slices e injeta announces no pai.
local store  = require("tools.subagents.store")
local policy = require("tools.subagents.policy")
local runner = require("tools.subagents.child_runner")
local M = {}

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function M.reconcile_orphans()
  local data = store.load()
  local changed = false
  for _, r in ipairs(data.runs) do
    if r.status == "queued" or r.status == "running" then
      r.status = "failed"
      r.error = "process_exit"
      r.finished_at = now_iso()
      r.updated_at = r.finished_at
      r.announce_pending = false
      changed = true
    end
  end
  if changed then store.save(data) end
  return changed
end

function M.tick(parent_ctx)
  local cfg = parent_ctx and parent_ctx.cfg
  local caps = policy.defaults(cfg)
  local advanced = 0

  -- Expira runs que já ultrapassaram runTimeoutSeconds (#84).
  for _, r in ipairs(store.list()) do
    if (r.status == "queued" or r.status == "running") and runner.is_timed_out(r) then
      runner.mark_timeout(r)
    end
  end

  local active = 0
  for _, r in ipairs(store.list()) do
    if r.status == "running" then active = active + 1 end
  end

  for _, r in ipairs(store.list({ status = "queued" })) do
    if active >= caps.maxConcurrent then break end
    runner.advance(r, cfg)
    advanced = advanced + 1
    if r.status == "running" then active = active + 1 end
  end
  return advanced
end

function M.inject_announces(parent_ctx)
  if not parent_ctx or not parent_ctx.msgs then return 0 end
  local n = 0
  for _, r in ipairs(store.list()) do
    if r.announce_pending and not r.announce_consumed then
      local body
      if r.status == "completed" then
        body = string.format(
          "[subagent runId=%s status=completed agentId=%s]\n%s",
          r.runId, tostring(r.agentId), r.result_text or ""
        )
      else
        body = string.format(
          "[subagent runId=%s status=%s agentId=%s]\nerror: %s",
          r.runId, tostring(r.status), tostring(r.agentId), tostring(r.error or "")
        )
      end
      parent_ctx.msgs[#parent_ctx.msgs + 1] = {
        role = "system",
        content = body,
      }
      r.announce_pending = false
      r.announce_consumed = true
      r.updated_at = now_iso()
      store.upsert(r)
      n = n + 1
    end
  end
  return n
end

function M.on_parent_boundary(parent_ctx)
  local ok, err = pcall(function()
    M.tick(parent_ctx)
    M.inject_announces(parent_ctx)
  end)
  if not ok then
    io.stderr:write("[subagents] boundary error: " .. tostring(err) .. "\n")
  end
end

return M
