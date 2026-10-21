-- tests/diag_log_spec.lua — Log estruturado: escrita, RSS, rotação e leitura do final.
package.path = "./?.lua;./?/init.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = "/tmp/termai_diag_test_" .. tostring(os.time()) .. "_" .. tostring(math.random(100000))
os.execute("mkdir -p '" .. root .. "'")
require("tools.agents.paths").base_override = root

local log  = require("diag.log")
local json = require("json")

log.info("teste_um", { run_id = "sub-1", n = 3 })
log.warn("teste_dois", { motivo = "x" })
local lines = log.tail(10)
check(#lines == 2, "duas linhas gravadas")
local first = json.decode(lines[1])
check(first.event == "teste_um" and first.level == "info" and first.n == 3, "campos e nível gravados")
check(type(first.t) == "number" and type(first.pid) == "number", "timestamp e pid presentes")

local rss_self = log.rss_kb()
check(type(rss_self) == "number" and rss_self > 0, "RSS do próprio processo lido de /proc")
check(log.rss_kb(999999999) == nil, "RSS de pid inexistente é nil (sem erro)")

-- Rotação: com limite pequeno, o arquivo atual vira .1 e o novo começa limpo.
log.MAX_BYTES = 200
for i = 1, 10 do log.info("bulk", { i = i, pad = string.rep("x", 40) }) end
local rotated = io.open(log.path() .. ".1", "r")
check(rotated ~= nil, "arquivo rotacionado ao passar do limite")
if rotated then rotated:close() end
check(#log.tail(100) < 10, "arquivo atual recomeça após a rotação")

log.enabled = true
print(failures == 0 and "\nTODOS OS TESTES PASSARAM" or ("\n" .. failures .. " FALHA(S)"))
os.exit(failures == 0 and 0 or 1)
