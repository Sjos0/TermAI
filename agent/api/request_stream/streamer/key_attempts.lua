local M = {}

function M.begin(ctx)
  if not ctx._fallback_suppress then ctx._key_attempt_summaries = {} end
  ctx._current_key_attempts = {}
end

function M.start_key(ctx, round)
  ctx._current_key_attempt_index = ctx.active.api_key_index or round
  ctx._current_key_attempt_count = 0
end

function M.start_attempt(ctx, attempt)
  ctx._current_key_attempt_count = attempt
end

function M.end_key(ctx)
  local attempts = ctx._current_key_attempts or {}
  attempts[#attempts + 1] = {
    index = ctx._current_key_attempt_index,
    attempts = ctx._current_key_attempt_count,
  }
  ctx._current_key_attempts = attempts
end

function M.finish(ctx, total)
  ctx._key_attempt_summaries = ctx._key_attempt_summaries or {}
  ctx._key_attempt_summaries[#ctx._key_attempt_summaries + 1] = {
    model = ctx.active and ctx.active.ref or "modelo",
    keys = ctx._current_key_attempts or {},
    total = total,
  }
  ctx._current_key_attempts = nil
end

return M
