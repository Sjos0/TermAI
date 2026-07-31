-- utils.lua — Helpers puros: configuração, auth, retry, tmp, tokens, tags.
local M = {}

M.BASE = (os.getenv("HOME") or "/data/data/com.termux/files/home") .. "/TermAI"

local _tmp_seq = 0

local function get_req_cfg(ctx)
  local req = ctx.cfg and ctx.cfg.agents and ctx.cfg.agents.defaults and ctx.cfg.agents.defaults.request or {}
  local wt  = req.wait_timeout or 0
  local default_mode = (wt > 0) and "buffer" or "stream"
  return {
    timeout      = req.timeout      or 180,
    idle_timeout = req.idle_timeout or 30,
    max_retries  = req.max_retries  or 10,
    mode         = req.retry_mode   or "exponential",
    static       = req.retry_static or 5,
    rmax         = req.retry_max    or 30,
    wait_timeout = wt,
    request_mode = req.mode         or default_mode,
  }
end

local function build_auth(active)
  local style = active.auth_style or ""
  if style == "bearer" then
    if active.api_key and active.api_key ~= "" then
      return ' -H "Authorization: Bearer ' .. active.api_key .. '"'
    end
  elseif style == "x-goog-api-key" then
    if active.api_key and active.api_key ~= "" then
      return ' -H "x-goog-api-key: ' .. active.api_key .. '"'
    end
  end
  return ""
end

local function wait_time(attempt, rcfg)
  if rcfg.mode == "static" then
    return rcfg.static
  end
  return math.min(2 ^ (attempt - 1), rcfg.rmax)
end

local function is_overflow_error(reason)
  if not reason then return false end
  local lower = reason:lower()
  return lower:match("request_too_large")
      or lower:match("context.length.exceeded")
      or lower:match("input exceeds the maximum")
      or lower:match("too many tokens")
      or lower:match("maximum context length")
end

local function strip_thinking_tags(text)
  -- Optimization (Bolt): Non-allocating fast check. If there's no '<' character, there can be no think/thought XML tags, so we can return early and avoid expensive regex matches.
  if not text or not text:find("<", 1, true) then return text end
  text = text:gsub("<[Tt]hink[^>]*>.-</[Tt]hink>", "")
  text = text:gsub("<[Tt]hought[^>]*>.-</[Tt]hought>", "")
  return text
end

-- Gera caminho de arquivo temporario usando TMPDIR (Termux-safe).
-- os.tmpname() usa /tmp hardcoded via mkstemp() no POSIX -- falha no Termux.
local function make_tmp_path()
  _tmp_seq = _tmp_seq + 1
  local d = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
  return d .. "/ta_payload_" .. tostring(os.time()) .. "_" .. tostring(_tmp_seq)
end

local function estimate_tokens(msgs)
  local total_chars, msg_count = 0, 0
  -- Optimization (Bolt): Standard numeric loop is faster than ipairs iterator in standard Lua
  for i = 1, #msgs do
    local msg = msgs[i]
    if msg then
      total_chars = total_chars + #(msg.content or "")
      msg_count   = msg_count + 1
    end
  end
  return math.ceil(total_chars / 3.5) + (msg_count * 4)
end

local function ensure_tokens(ctx)
  local estimated = estimate_tokens(ctx.msgs)
  if not ctx.tokens or ctx.tokens == 0 or ctx.tokens < estimated then
    ctx.tokens = estimated
  end
end

M.get_req_cfg         = get_req_cfg
M.build_auth          = build_auth
M.wait_time           = wait_time
M.is_overflow_error   = is_overflow_error
M.strip_thinking_tags = strip_thinking_tags
M.make_tmp_path       = make_tmp_path
M.estimate_tokens     = estimate_tokens
M.ensure_tokens       = ensure_tokens
return M
