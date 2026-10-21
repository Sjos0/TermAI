-- e2e/kilo_smoke.lua — Smoke real: o modelo Kilo (kilo-auto/free, sem chave) responde via TermAI run.
package.path = "./?.lua;./?/init.lua;" .. package.path
local config = require("config")
require("e2e.common").ensure_kilo()
local log    = require("diag.log")

local MODEL   = "kilo/kilo-auto/free"
local out_dir = os.getenv("E2E_OUT") or "/tmp/termai-e2e"
local home    = os.getenv("HOME")
os.execute(string.format("mkdir -p '%s'", out_dir))

config.set("agents.defaults.model.primary", MODEL)

local cmd = string.format("lua5.4 '%s/TermAI/main.lua' run --prompt 'Responda apenas com a palavra OK.' 2>&1", home)
local h = io.popen(cmd)
local output = h:read("*a") or ""
local _, _, code = h:close()

local passed = (code == 0) and output:lower():find("ok", 1, true) ~= nil
local f = io.open(out_dir .. "/smoke.log", "w"); f:write(output); f:close()

local report = { check = "smoke_kilo", model = MODEL, exit_code = code, passed = passed,
  output_chars = #output, t = os.time() }
f = io.open(out_dir .. "/smoke.json", "w"); f:write(require("json").encode(report)); f:close()
log.info("e2e_smoke", { model = MODEL, exit_code = code, passed = passed })

print(passed and "SMOKE OK" or ("SMOKE FALHOU (exit=" .. tostring(code) .. ")"))
os.exit(passed and 0 or 1)
