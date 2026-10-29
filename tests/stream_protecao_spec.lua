-- tests/stream_protecao_spec.lua — parte_1.lua: erro interno no loop de leitura
-- não vaza sem fechar o pipe e remover o payload temporário (#183).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local dir = os.getenv("TMPDIR") or "/tmp"
local closed = false
local removed = false
local tmp_path = dir .. "/fake_payload_stream_1"

-- handle fake de io.popen: uma linha "data:" que dispara process_tokens (que lança erro)
local fake_h = {
  lines = function()
    local data = { 'data: {"choices":[{"delta":{"content":"x"}}]}' }
    local i = 0
    return function()
      i = i + 1
      return data[i]
    end
  end,
  close = function() closed = true; return true end,
}

local real_popen = io.popen
local real_remove = os.remove
io.popen = function() return fake_h end
os.remove = function(p) if p == tmp_path then removed = true end return real_remove(p) end

-- mock do fallback (usado no topo do parte_1)
package.loaded["agent.api.request_stream.streamer.fallback"] = function(M)
  return {
    tentar_fallbacks = function() return nil, "fallback" end,
    falha_final = function() return "[ERRO] falha final", false, nil, "" end,
  }
end

local N = {
  json = { decode = function(s) return true, {} end },
  ui = {
    stream_start = function() end,
    stream_confirm = function() end,
    stream_reasoning = function() end,
    stream_token = function() end,
    stream_end = function() return "", "" end,
    kill_spinner = function() end,
    show_retry = function() end,
    restart_spinner = function() end,
  },
  thinking_parser = {
    reset = function() end,
    feed = function() end,
    flush = function() end,
  },
  utils = {
    get_req_cfg = function() return { max_retries = 1, request_mode = "stream", timeout = 10, idle_timeout = 5 } end,
    build_auth = function() return "" end,
    make_tmp_path = function() return tmp_path end,
    ensure_tokens = function() end,
    is_overflow_error = function() return false end,
    wait_time = function() return 0 end,
  },
  payload_mod = {
    build_payload = function() return "{}" end,
  },
  sync_mod = {
    pensar_sync = function() return "", false, nil end,
  },
  tool_parser = {
    feed = function() end,
    filter = function() return {} end,
    parse = function() return nil end,
    raw = function() return {} end,
  },
  recovery = {},
  tokens_mod = {
    process_tokens = function() error("erro injetado no processamento") end,
  },
  error_log = {
    extract_from_body = function() return "erro" end,
    record = function() end,
  },
}

local M = {}
local parte1 = require("agent.api.request_stream.streamer.parte_1")
parte1(M, N)

local ctx = { active = {}, msgs = {}, cfg = { agents = { defaults = { request = {} } } } }
local resp, overflow, done, reasoning = M.pensar_stream(ctx, "oi", "user")

io.popen = real_popen
os.remove = real_remove

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

check(closed, "pipe foi fechado mesmo com erro interno no loop")
check(removed, "payload temporário foi removido mesmo com erro interno")
check(overflow == false, "não marca como overflow (é erro interno)")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
