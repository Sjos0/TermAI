-- tests/update_release_spec.lua — Release (#74), restart (#53), /models (#67), caminhos (#83), artefato (#47).
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local function sh(cmd)
  local h = io.popen(cmd .. " 2>/dev/null"); local s = h:read("*a") or ""; h:close(); return s
end

-- (1) Regras do update por release.
local rel = require("tools.update.release")
check(rel.parse_tag('{"tag_name":"v1.22.10.2026","name":"x"}') == "v1.22.10.2026", "parse_tag lê tag_name da release")
check(rel.parse_tag('{"tag_name": "v1.2.0"}') == "v1.2.0", "parse_tag aceita espaços no JSON")
check(rel.parse_tag('{"name":"sem tag"}') == nil, "parse_tag sem tag_name devolve nil")
check(rel.parse_tag('{"tag_name":"v1; rm -rf ~"}') == nil, "parse_tag recusa tag com caracteres perigosos")
check(rel.parse_tag(nil) == nil, "parse_tag com corpo nulo devolve nil")
check(rel.ref_for("release", "v1.22.10.2026") == "v1.22.10.2026", "ref_for release aponta para a tag")
check(rel.ref_for("main", "v1.22.10.2026") == "origin/main", "ref_for main aponta para origin/main")

local home = "/tmp/termai_upd_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
os.execute("mkdir -p '" .. home .. "/.TermAI'")
check(rel.read_previous(home) == nil, "sem update anterior, read_previous é nil")
local sha = "0123456789abcdef0123456789abcdef01234567"
check(rel.save_previous(home, sha), "save_previous grava o commit anterior")
check(rel.read_previous(home) == sha, "read_previous devolve o commit guardado")
local f = io.open(home .. "/.TermAI/update_previous", "w"); f:write("lixo; rm -rf /\n"); f:close()
check(rel.read_previous(home) == nil, "read_previous recusa conteúdo que não é um SHA")
os.execute("rm -rf '" .. home .. "'")

-- (2) #53: "TermAI restart" sai com 123 (o wrapper reinicia). Antes só marcava e saía com 0.
local code
local real_exit = os.exit
os.exit = function(c) code = c; error("__exit__", 0) end
pcall(dofile, "commands/restart.lua")
os.exit = real_exit
check(code == 123, "comando restart sai com código 123 (era 0 sem reinício)")

-- (3) #67: /models chama lua5.4, não "lua" (no Termux o binário é lua5.4).
check(sh("grep -rn 'os.execute(\"lua ' agent commands ui tools"):gsub("%s", "") == "",
      "nenhum os.execute(\"lua ...) restante")

-- (4) #83: nenhum caminho /home/ubuntu fixo no código nem nos scripts.
check(sh("grep -rln '/home/ubuntu' commands agent scripts tools ui main.lua"):gsub("%s", "") == "",
      "nenhum /home/ubuntu fixo em commands, agent, scripts, tools, ui ou main.lua")

-- (5) #47: artefato solto removido da raiz.
local g = io.open("test_sync_check.txt", "r")
check(g == nil, "test_sync_check.txt removido da raiz")
if g then g:close() end

-- (6) Versão: formato 1.<dia>.<mês>.<ano> e data de hoje (22/10/2026).
local v = (io.open("VERSION"):read("*a") or ""):gsub("%s", "")
check(v == "1.22.10.2026", "VERSION é 1.22.10.2026 (data de hoje)")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
