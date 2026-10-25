-- tests/subagents_retention_spec.lua — PR-B: retenção (#94), salvage no timeout (#93),
-- teto e cabeçalho do anúncio e classe do erro (#96).
package.path = "./?.lua;./?/init.lua;" .. package.path
local portable_tmp = require("tests.helpers.tmp")

local failures = 0
local function check(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local root = portable_tmp.name("termai_ret_test")
os.execute("mkdir -p '" .. root .. "'")
require("tools.agents.paths").base_override = root
local registry = require("tools.subagents.registry")
local cleanup  = require("tools.subagents.cleanup")
local snapshot = require("tools.subagents.snapshot")
local announce = require("tools.subagents.announce")
local ecls     = require("tools.subagents.error_class")

local NOW = 2000000000
local function run(id, o)
  local rec = { runId = id, kind = "clone", agentId = "main", task = "t", status = o.status or "completed",
    created_at = NOW - 100, started_at = NOW - 90, finished_at = NOW - 10,
    parent_agent = "main", cleanup = o.cleanup or "retain", announce_consumed = o.consumed ~= false,
    announced_at = o.announced_at }
  registry.save(rec)
  if o.result then registry.write_result(id, o.result) end
  return id
end
local function exists(id) return registry.load(id) ~= nil end

-- (1) #94 — 55 runs anunciados: guarda os 50 mais recentes e apaga os 5 mais antigos.
for i = 1, 55 do run(string.format("sub-%x", 0x100 + i), { announced_at = NOW - i }) end
local removed = cleanup.sweep(NOW)
check(removed == 5, "teto de 50: remove exatamente 5 (removeu " .. removed .. ")")
check(exists("sub-101") and exists("sub-132"), "teto de 50: mantém os 50 mais recentes")
check(not exists("sub-133") and not exists("sub-137"), "teto de 50: remove os mais antigos")

-- (2) #94 — 7 dias: apaga o que passou do prazo, mantém o recente.
for i = 1, 50 do registry.remove(string.format("sub-%x", 0x100 + i)) end  -- isola a regra do TTL
run("sub-a1", { announced_at = NOW - 8 * 24 * 3600 })
run("sub-a2", { announced_at = NOW - 3600 })
cleanup.sweep(NOW)
check(not exists("sub-a1"), "TTL: run com mais de 7 dias é removido")
check(exists("sub-a2"), "TTL: run recente é mantido")

-- (3) cleanup explícito: delete apaga logo; keep nunca apaga; run ativo nunca é tocado.
run("sub-a3", { cleanup = "delete", announced_at = NOW - 1 })
run("sub-a4", { cleanup = "keep", announced_at = NOW - 99999999 })
run("sub-a5", { status = "running", consumed = false, announced_at = NOW - 99999999 })
cleanup.sweep(NOW)
check(not exists("sub-a3"), "delete: removido logo após o anúncio")
check(exists("sub-a4"), "keep: nunca removido, mesmo antigo")
check(exists("sub-a5"), "run ativo nunca é removido")

-- (4) #93 — snapshot: grava o último texto útil, redigido, no máximo a cada 10 s.
local ctx = { is_subagent = true, run_id = "sub-a6", msgs = { { role = "assistant", content = "parcial ghp_SECRET1 ok" } } }
run("sub-a6", { status = "running", consumed = false })
check(snapshot.tick(ctx, NOW) == true, "snapshot: grava na primeira vez")
local f = io.open(registry.dir("sub-a6") .. "/result.partial.txt", "r")
local ptxt = f and f:read("*a") or ""
if f then f:close() end
check(ptxt:find("parcial", 1, true) ~= nil and not ptxt:find("SECRET1", 1, true), "snapshot: texto gravado sem segredo")
check(snapshot.tick(ctx, NOW + 3) == false, "snapshot: mesmo texto não regrava")
ctx.msgs[1].content = "texto novo"
check(snapshot.tick(ctx, NOW + 5) == false, "snapshot: dentro de 10 s não regrava")
check(snapshot.tick(ctx, NOW + 11) == true, "snapshot: após 10 s regrava o texto novo")

-- (5) #93 — salvage: run sem resultado vira resultado parcial; com resultado, não mexe.
run("sub-a7", { status = "timeout", consumed = false })
registry.write_partial("sub-a7", "trabalho até o kill")
check(registry.promote_partial("sub-a7") == true, "salvage: promove o parcial quando não há resultado")
check(registry.read_result("sub-a7") == "trabalho até o kill", "salvage: resultado = parcial salvo")
run("sub-a8", { consumed = false, result = "final" })
registry.write_partial("sub-a8", "parcial velho")
check(registry.promote_partial("sub-a8") == false and registry.read_result("sub-a8") == "final",
      "salvage: não sobrescreve resultado completo")

-- (6) #96 — classe do erro, com os padrões reais do log.
check(ecls.of("[ERRO] Falha apos 5 tentativas - Sem resposta do servidor") == "network", "classe: sem resposta -> network")
check(ecls.of("HTTP 429 rate limit") == "rate_limit", "classe: 429 -> rate_limit")
check(ecls.of("contexto estourou o limite") == "context_overflow", "classe: contexto -> context_overflow")
check(ecls.of("runTimeoutSeconds excedido") == "timeout", "classe: prazo -> timeout")
check(ecls.of("process_exit") == "killed", "classe: morte -> killed")
check(ecls.of("algo estranho") == "provider", "classe: sem padrão -> provider (default)")

-- (7) #96 — anúncio: cabeçalho com duração e tools; corpo com teto de 8 KB e ponteiro.
run("sub-a9", { consumed = false, result = string.rep("á", 9000) })
local ctx2 = { agent_id = "main", msgs = {} }
local out = {}
local orig = io.write
io.write = function(...) for _, v in ipairs({ ... }) do out[#out + 1] = tostring(v) end end
announce.inject(ctx2)
io.write = orig
local msg = ""
for _, m in ipairs(ctx2.msgs) do
  if m.content and m.content:find("sub-a9", 1, true) then msg = m.content end
end
check(msg:find("duracao=80s", 1, true) ~= nil, "anúncio: cabeçalho traz duracao")
check(msg:find("tools=0", 1, true) ~= nil, "anúncio: cabeçalho traz tools")
check(#msg <= 8192 + 400, "anúncio: corpo limitado a 8 KB (tamanho " .. #msg .. ")")
check(msg:find("anúncio cortado", 1, true) ~= nil and msg:find("result.txt", 1, true) ~= nil,
      "anúncio: corte aponta o resultado completo em result.txt")
check(utf8.len(msg) ~= nil, "anúncio: corte não parte caractere UTF-8")

os.execute("rm -rf '" .. root .. "'")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
