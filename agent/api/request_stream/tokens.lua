-- agent/api/request_stream/tokens.lua — Validador de queda e atualização de tokens da API.
local utils = require("agent.api.utils")
local M = {}

function M.process_tokens(ctx, chunk)
  if not (chunk.usage and chunk.usage.total_tokens) then
    return false
  end

  local new_tok = chunk.usage.total_tokens
  local prev_tok = ctx.tokens or 0
  local estimated = utils.estimate_tokens(ctx.msgs)

  local drop_is_suspicious = false
  if prev_tok > 0 and new_tok < prev_tok * 0.5 then
    if new_tok < estimated * 0.7 then
      drop_is_suspicious = true
    end
  end

  if drop_is_suspicious then
    local d = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
    local logf = io.open(d .. "/termai_debug.log", "a")
    if logf then
      logf:write(string.format("[%s] Queda suspeita bloqueada: provider=%d prev=%d est=%d\n",
        os.date("%Y-%m-%d %H:%M:%S"), new_tok, prev_tok, estimated))
      logf:close()
    end
    return false, false
  else
    ctx.tokens = new_tok
    return true, true
  end
end

return M
