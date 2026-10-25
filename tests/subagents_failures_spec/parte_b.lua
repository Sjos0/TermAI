-- tests/subagents_failures_spec/parte_b.lua — cenários restantes: deadline do SO e retomada depois que o orquestrador morre.
local C = require("tests.subagents_failures_spec.contexto")
local announce, check, fresh_root, launcher, new_run, registry, scheduler = C.announce, C.check, C.fresh_root, C.launcher, C.new_run, C.registry, C.scheduler

local M = {}

function M.run()
  -- (5) Orquestrador morreu: o estado persiste e a retomada é correta e idempotente.
  fresh_root()
  launcher.exec.execute = function() return false end   -- nenhum pid vivo
  launcher.exec.cmdline = function() return nil end
  local ida = new_run({ status = "completed", finished_at = os.time(), announce_pending = true })
  registry.write_result(ida, "RESULTADO-A")
  local idb = new_run({ status = "running", pid = 5555, started_at = os.time() - 5, timeout_seconds = 600 })
  scheduler.tick({})
  check(registry.load(idb).status == "failed" and registry.load(idb).error == "process_exit",
        "pid morto antes do prazo: failed/process_exit")
  local ctx = { agent_id = "main", msgs = {} }
  local n1 = announce.inject(ctx)
  local n2 = announce.inject(ctx)
  check(n1 == 2 and n2 == 0, "anúncio entrega cada run uma única vez (1ª=" .. n1 .. ", 2ª=" .. n2 .. ")")

  -- (5b) run.json corrompido não derruba listagem nem anúncio.
  fresh_root()
  os.execute("mkdir -p '" .. registry.base() .. "/sub-deadbeef'")
  local f = io.open(registry.base() .. "/sub-deadbeef/run.json", "w"); f:write("{ isto nao e json"); f:close()
  local okc, errc = pcall(function() registry.list(); announce.inject({ agent_id = "main", msgs = {} }) end)
  check(okc, "run.json corrompido não derruba list/inject" .. (okc and "" or (": " .. tostring(errc))))

  -- (6) O anúncio de falha diz o motivo, entrega o parcial e orienta o orquestrador.
  fresh_root()
  local idp = new_run({ status = "failed", partial = true, error = "resposta incompleta (stream cortado)",
                        finished_at = os.time() })
  registry.write_result(idp, "TEXTO-PARCIAL")
  local pctx = { agent_id = "main", msgs = {} }
  announce.inject(pctx)
  local msg = pctx.msgs[1] and pctx.msgs[1].content or ""
  check(msg:find("resposta incompleta", 1, true) ~= nil, "anúncio de falha inclui o motivo")
  check(msg:find("TEXTO-PARCIAL", 1, true) ~= nil, "anúncio de falha inclui o resultado parcial")
  check(msg:find("NÃO foi concluído", 1, true) ~= nil, "anúncio de falha avisa que o trabalho não foi concluído")

  -- (7) Tentativas de requisição do filho viram eventos; o pai não grava nada.
  fresh_root()
  local events = require("tools.subagents.events")
  local idr = new_run({ status = "running" })
  events.retry({ is_subagent = true, run_id = idr }, 2, 5, "HTTP 429", 8)
  events.retry({ run_id = idr }, 3, 5, "ignorado", 8)
  local tail = events.tail(idr, 10)
  check(#tail == 1 and tail[1]:find("2/5", 1, true) and tail[1]:find("HTTP 429", 1, true),
        "retry do filho vira evento e o pai não grava")

end

return M
