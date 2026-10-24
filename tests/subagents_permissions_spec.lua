package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
-- tests/subagents_permissions_spec.lua — Permissões das tools de subagentes (headless-safe).
package.path = "./?.lua;./?/init.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = portable_tmp.name("termai_perm_test")
os.execute("mkdir -p '" .. root .. "'")
require("config.store").PATH = root .. "/config.json"
require("config.store")._data = nil

local permcheck = require("tools.exec.permissions.check")

-- Internas: liberadas sem diálogo (inclusive headless).
for _, name in ipairs({ "sessions_spawn", "subagents_list", "subagents_info", "subagents_log", "subagents_wait" }) do
  local r = permcheck.check(name, nil)
  check(r.allowed == true, name .. " liberada sem diálogo")
end

-- Sensíveis: continuam pedindo confirmação.
for _, name in ipairs({ "subagents_kill", "agents_create" }) do
  local r = permcheck.check(name, nil)
  check(r.allowed == false and r.reason == "ask", name .. " continua exigindo confirmação")
end

-- Tools de arquivo: sem mudança de comportamento (continuam pedindo).
local r_read = permcheck.check("Read", nil)
check(r_read.allowed == false and r_read.reason == "ask", "Read continua pedindo permissão fora do probe")

os.execute("rm -rf '" .. root .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
