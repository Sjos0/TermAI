-- tests/agente_boot_real_spec.lua — #238: boot real via subprocesso, sem stubs.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local src = assert(io.open("agente.lua", "r")):read("*a")
local bad_line = nil
for line in (src .. "\n"):gmatch("([^\n]*)\n") do
  if line:match("pcall%s*%b()%.%s*[%w_]+") then bad_line = line; break end
end
T(bad_line == nil, "agente.lua sem pcall(...).campo")

local home = "/tmp/termai_boot_home_" .. tostring(os.time())
local tmp  = "/tmp/termai_boot_tmp_" .. tostring(os.time())
os.execute("mkdir -p '" .. home .. "/.TermAI/agents/main/agent' '" .. home .. "/.TermAI/workspace' '" .. tmp .. "'")

-- config + modelo mínimo para context.build não sair com "nenhum modelo"
local cfg = [[{
  "meta": {"version": "0.1.0"},
  "agents": {
    "defaults": {
      "model": {"primary": "test/dummy", "fallbacks": []},
      "maxIter": 5,
      "request": {"timeout": 5, "max_retries": 1}
    },
    "list": [{"id": "main", "workspace": "workspace", "model": {"primary": "test/dummy"}}]
  }
}]]
local models = [[{
  "active": "test/dummy",
  "providers": {
    "test": {
      "baseUrl": "http://127.0.0.1:9",
      "apiKey": "",
      "api": "openai-completions",
      "models": [{"id": "dummy", "name": "dummy"}]
    }
  }
}]]
local f = io.open(home .. "/.TermAI/config.json", "w"); f:write(cfg); f:close()
f = io.open(home .. "/.TermAI/agents/main/agent/models.json", "w"); f:write(models); f:close()

local function which_lua()
  for _, c in ipairs({ "/tmp/lua-5.4.7/src/lua", "lua5.4", "lua54", "lua" }) do
    local h = io.popen("command -v " .. c .. " 2>/dev/null || test -x " .. c .. " && echo " .. c)
    local p = h and h:read("*l") or ""
    if h then h:close() end
    if p and p ~= "" then return p end
  end
  return "lua5.4"
end
local lua = which_lua()
local cwd = (io.popen("pwd"):read("*l")) or "."
local log = tmp .. "/boot.log"
-- package.path igual ao main.lua: BASE = HOME/TermAI → link simbólico
os.execute("ln -sfn '" .. cwd .. "' '" .. home .. "/TermAI'")

local cmd = string.format(
  "cd '%s' && HOME='%s' TMPDIR='%s' TERMAI_BOOT_ONLY=1 %s -e \"package.path='%s/?.lua;%s/?/init.lua;%s/lib/?.lua;'..package.path; dofile('agente.lua')\" </dev/null >'%s' 2>&1; echo EXIT:$? >>'%s'",
  cwd, home, tmp, lua, cwd, cwd, cwd, log, log
)
os.execute(cmd)
local out = ""
local lf = io.open(log, "r")
if lf then out = lf:read("*a") or ""; lf:close() end

T(out:match("EXIT:0") ~= nil, "subprocesso EXIT 0 (log tem EXIT:0)")
T(not out:find("attempt to index", 1, true), "sem attempt to index")
T(not out:find("attempt to call a nil", 1, true), "sem attempt to call a nil")
T(not out:find("bad argument", 1, true), "sem bad argument")

os.execute("rm -rf '" .. home .. "' '" .. tmp .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
if failures > 0 then print("--- boot log ---\n" .. out) end
os.exit(failures == 0 and 0 or 1)
