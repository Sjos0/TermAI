-- tools/subagents/child_runner.lua — Avança um slice cooperativo de um child run.
-- v2: aplica runTimeoutSeconds (#84); restaura _G.__termai_ctx após o filho;
--     task única via loop.rodar (#85).
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

-- Converte created_at ISO (ou started_at_unix) em epoch aproximado.
local function started_epoch(run)
  if type(run.started_at_unix) == "number" then
    return run.started_at_unix
  end
  -- Fallback: os.time() no momento do check se nunca gravou.
  return os.time()
end

function M.is_timed_out(run)
  local limit = tonumber(run.timeout_seconds)
  if not limit or limit <= 0 then return false end
  local start = started_epoch(run)
  return (os.time() - start) >= limit
end

function M.mark_timeout(run)
  run.status = "timeout"
  run.error = "runTimeoutSeconds exceeded (" .. tostring(run.timeout_seconds) .. "s)"
  run.finished_at = now_iso()
  run.updated_at = run.finished_at
  run.announce_pending = true
  store.upsert(run)
  return run
end

function M.advance(run, parent_cfg)
  if run.status == "completed" or run.status == "failed"
     or run.status == "timeout" then
    return run
  end

  -- Timeout antes de gastar um slot de execução (#84).
  if run.status == "running" and M.is_timed_out(run) then
    return M.mark_timeout(run)
  end
  if run.status == "queued" and type(run.created_at_unix) == "number" then
    local limit = tonumber(run.timeout_seconds)
    if limit and limit > 0 and (os.time() - run.created_at_unix) >= limit then
      return M.mark_timeout(run)
    end
  end

  run.status = "running"
  if not run.started_at_unix then
    run.started_at_unix = os.time()
  end
  run.updated_at = now_iso()
  store.upsert(run)

  if M.is_timed_out(run) then
    return M.mark_timeout(run)
  end

  local ctx, err = child_ctx.build(run, parent_cfg)
  if not ctx then
    run.status = "failed"
    run.error = err
    run.finished_at = now_iso()
    run.announce_pending = true
    store.upsert(run)
    return run
  end

  -- Preserva ctx do pai; loop.rodar sobrescreve _G.__termai_ctx.
  local prev_global_ctx = _G.__termai_ctx

  local ok, result = pcall(function()
    local loop = require("agent.loop")
    -- Task entra uma única vez aqui (child_ctx não pré-insere user) — #85.
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

  -- Restaura global do pai (achado Caçador #5).
  _G.__termai_ctx = prev_global_ctx

  -- Timeout pós-execução: se o wall-clock estourou durante o rodar.
  if M.is_timed_out(run) and ok then
    run.result_text = (result and result.resp) or run.result_text
    return M.mark_timeout(run)
  end

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
