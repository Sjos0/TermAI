-- tools/subagents/child_runner.lua — Avança um slice cooperativo de um child run.
local json      = require("json")
local store     = require("tools.subagents.store")
local child_ctx = require("tools.subagents.child_ctx")
local M = {}

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function append_transcript(path, entry)
  if not path then return end
  local f = io.open(path, "a")
  if not f then return end
  f:write(json.encode(entry) .. "\n")
  f:close()
end

function M.advance(run, parent_cfg)
  if run.status == "completed" or run.status == "failed" or run.status == "timeout" then
    return run
  end

  run.status = "running"
  run.updated_at = now_iso()
  store.upsert(run)

  local ctx, err = child_ctx.build(run, parent_cfg)
  if not ctx then
    run.status = "failed"
    run.error = err
    run.finished_at = now_iso()
    run.announce_pending = true
    store.upsert(run)
    return run
  end

  local ok, result = pcall(function()
    local loop = require("agent.loop")
    local resp, elapsed, flush_done, is_overflow, stream_complete, reasoning =
      loop.rodar(ctx, run.task, "user", ctx.MAX_ITER)
    return {
      resp = resp or "",
      elapsed = elapsed,
      overflow = is_overflow,
      stream_complete = stream_complete,
      reasoning = reasoning,
    }
  end)

  if not ok then
    run.status = "failed"
    run.error = tostring(result)
    run.result_text = nil
  else
    local text = (result.resp and tostring(result.resp)) or ""
    if (text == "" or text == nil) and ctx.msgs then
      for i = #ctx.msgs, 1, -1 do
        local m = ctx.msgs[i]
        if m.role == "assistant" and m.content and m.content ~= "" then
          text = m.content
          break
        end
      end
    end
    run.result_text = text
    if result.overflow then
      run.status = "failed"
      run.error = "context overflow"
    else
      run.status = "completed"
    end
  end

  run.finished_at = now_iso()
  run.updated_at = run.finished_at
  run.announce_pending = true
  append_transcript(run.transcript_path, {
    type = "message",
    role = "assistant",
    content = run.result_text or ("[error] " .. tostring(run.error)),
    timestamp = run.finished_at,
    status = run.status,
  })
  store.upsert(run)
  return run
end

return M
