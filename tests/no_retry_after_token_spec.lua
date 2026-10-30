-- tests/no_retry_after_token_spec.lua — #239: exercita streamer real (parte_1) com transporte falso.
-- Injeção: substitui io.popen (único ponto de HTTP no streamer). Sem cópia da lógica de retry.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- --- Transporte falso (conta chamadas HTTP) ---
local http_calls = 0
local mode = "A" -- A: 1 token + erro de leitura; B: zero tokens
local real_popen = io.popen

local function make_handle(lines)
  local i = 0
  return {
    lines = function()
      return function()
        i = i + 1
        if mode == "A" and i == 2 then
          -- após 1ª linha de data, explode o loop de leitura
          error("transporte: falha apos token")
        end
        return lines[i]
      end
    end,
    close = function()
      -- A: close falha (stream incompleto); B: close ok mas sem data
      if mode == "A" then return nil end
      return true
    end,
  }
end

io.popen = function(cmd)
  http_calls = http_calls + 1
  if mode == "A" then
    local chunk = '{"choices":[{"delta":{"content":"ola"}}]}'
    return make_handle({ "data: " .. chunk })
  else
    return make_handle({ "HTTP/1.1 500", "error" })
  end
end

-- Evita sleep real nos retries
local real_execute = os.execute
os.execute = function(cmd)
  if type(cmd) == "string" and cmd:match("^sleep ") then return true end
  return real_execute(cmd)
end

-- Stubs de dependências de IO/TUI; lógica de retry/stream fica em parte_1
local tokens = {}
package.loaded["ui.core"] = package.loaded["ui.core"] or {
  c = { red="", reset="", orange="", gray="", bg_error="" },
  tw = function() return 40 end,
  wlen = function(s) return #tostring(s or "") end,
}
local ui = {
  stream_start = function() end,
  stream_confirm = function() end,
  stream_end = function() return table.concat(tokens), "" end,
  stream_token = function(t) tokens[#tokens + 1] = t end,
  stream_reasoning = function() end,
  kill_spinner = function() end,
  restart_spinner = function() end,
  show_retry = function() end,
  show_api_error = function() end,
}
local thinking_parser = {
  reset = function() end,
  flush = function(a, b) end,
  feed = function(content, r, t) if t and content then t(content) end end,
}
local utils = require("agent.api.utils")
-- força max_retries baixo e wait 0
local orig_cfg = utils.get_req_cfg
utils.get_req_cfg = function(ctx)
  local c = orig_cfg(ctx)
  c.max_retries = 3
  c.mode = "static"
  c.static = 0
  c.rmax = 0
  return c
end
utils.wait_time = function() return 0 end

package.loaded["tools.subagents.events"] = { retry = function() end }

local N = {
  json = require("json"),
  ui = ui,
  thinking_parser = thinking_parser,
  utils = utils,
  payload_mod = { build_payload = function() return '{"model":"x","messages":[]}' end },
  sync_mod = { pensar_sync = function() return "sync", false, nil end },
  tool_parser = {
    feed = function() end,
    filter = function() return {} end,
    parse = function() return nil end,
    raw = function() return {} end,
  },
  recovery = {},
  tokens_mod = { process_tokens = function() return true, false end },
  error_log = {
    extract_from_body = function() return "erro server" end,
    record = function() end,
  },
}

package.loaded["ui"] = ui
package.loaded["ui.spinner.retry"] = {
  show_retry = function() end,
  show_api_error = function() end,
  clear_retry_lines = function() end,
}
local M = {}
require("agent.api.request_stream.streamer.parte_1")(M, N)

local ctx = {
  msgs = {},
  cfg = { agents = { defaults = { request = { max_retries = 3, retry_mode = "static", retry_static = 0 } } } },
  active = { endpoint = "http://127.0.0.1:9/v1", auth_style = "", api_key = "" },
}

-- Cenário A: 1 token depois falha → 1 HTTP, texto parcial, stream_complete false
mode = "A"
http_calls = 0
tokens = {}
local full, overflow, finished = M.pensar_stream(ctx, "hi", "user")
T(http_calls == 1, "A: uma unica chamada HTTP (got=" .. tostring(http_calls) .. ")")
T(type(full) == "string" and full:find("ola", 1, true), "A: texto parcial devolvido")
T(finished == false, "A: stream_complete/finished false")
T(overflow == false, "A: nao overflow")

-- Cenário B: sem token → retries até max
mode = "B"
http_calls = 0
tokens = {}
ctx.msgs = {}
local full2, ov2, fin2 = M.pensar_stream(ctx, "hi", "user")
T(http_calls == 3, "B: retries ate max_retries=3 (got=" .. tostring(http_calls) .. ")")

-- Complemento: código real não zera got_data
local src = assert(io.open("agent/api/request_stream/streamer/parte_1.lua", "r")):read("*a")
T(not src:find("got_data = false"), "codigo real sem got_data = false")

io.popen = real_popen
os.execute = real_execute
utils.get_req_cfg = orig_cfg

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
