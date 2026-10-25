-- tests/subagents_failures_spec/parte_a.lua — cenários (1) a (k): requisição esgotada, stream cortado e PID reaproveitado.
local C = require("tests.subagents_failures_spec.contexto")
local api, check, fresh_root, launcher, new_run, registry, worker = C.api, C.check, C.fresh_root, C.launcher, C.new_run, C.registry, C.worker

local M = {}

function M.run()
  -- (1) Requisição esgotou as tentativas: o filho NÃO pode terminar como completed.
  fresh_root()
  api.pensar_stream = function() return "[ERRO] Falha apos 5 tentativas - Sem resposta do servidor", false, nil, "" end
  local id1 = new_run({ status = "running" })
  local ok1 = worker.execute(id1)
  local r1 = registry.load(id1)
  check(ok1 == false, "requisição esgotada: worker.execute retorna false")
  check(r1.status == "failed", "requisição esgotada: status failed (veio " .. tostring(r1.status) .. ")")
  check(tostring(r1.error):find("Falha apos 5 tentativas", 1, true) ~= nil, "requisição esgotada: error carrega o motivo")

  -- (2) Stream cortado no meio: falha marcada como parcial, com o texto parcial preservado.
  fresh_root()
  api.pensar_stream = function() return "resposta pela meta", false, false, "" end
  local id2 = new_run({ status = "running" })
  worker.execute(id2)
  local r2 = registry.load(id2)
  check(r2.status == "failed", "stream cortado: status failed (veio " .. tostring(r2.status) .. ")")
  check(r2.partial == true, "stream cortado: run marcado como partial")
  check(registry.read_result(id2) == "resposta pela meta", "stream cortado: texto parcial preservado em result.txt")
  check(tostring(r2.error):find("incompleta", 1, true) ~= nil, "stream cortado: error explica que a resposta ficou incompleta")

  -- (2b) Sanidade: resposta normal continua completed.
  fresh_root()
  api.pensar_stream = function() return "PONG", false, true, "" end
  local id3 = new_run({ status = "running" })
  local ok3 = worker.execute(id3)
  check(ok3 == true and registry.load(id3).status == "completed" and registry.read_result(id3) == "PONG",
        "resposta normal continua completed")

  -- (3) PID reaproveitado por outro programa não conta como vivo e não recebe kill.
  local sent = {}
  launcher.exec.execute = function(cmd) sent[#sent + 1] = cmd; return true end
  launcher.exec.cmdline = function() return "/usr/bin/python3 outro-programa" end
  check(launcher.alive(777, "sub-abc") == false, "PID reaproveitado: não conta como vivo")
  sent = {}
  launcher.kill(777, "sub-abc")
  local signaled = false
  for _, c in ipairs(sent) do if c:find("kill -TERM", 1, true) then signaled = true end end
  check(not signaled, "PID reaproveitado: kill não sinaliza o outro programa")
  launcher.exec.cmdline = function() return "lua5.4 /x/main.lua run --worker sub-abc" end
  check(launcher.alive(777, "sub-abc") == true, "PID do próprio worker conta como vivo")
  launcher.exec.cmdline = function() return nil end
  check(launcher.alive(777, "sub-abc") == true, "identidade ilegível: mantém o kill -0 de antes")

  -- (4) O filho sobe sob o deadline do sistema (timeout), mesmo que o pai morra.
  local cmds = {}
  launcher.exec.popen = function(cmd)
    cmds[#cmds + 1] = cmd
    return { read = function() return "4242\n" end, close = function() end }
  end
  launcher.exec.execute = function() return true end
  launcher._has_timeout = nil
  local pid = launcher.start("sub-abc1", 600)
  check(pid == 4242, "start devolve o pid")
  check(cmds[1]:find("timeout", 1, true) ~= nil and cmds[1]:find("630", 1, true) ~= nil,
        "start aplica deadline do SO (600s + 30s de folga)")
  launcher.exec.execute = function(cmd)
    if cmd:find("command -v timeout", 1, true) then return false end
    return true
  end
  launcher._has_timeout = nil
  cmds = {}
  launcher.start("sub-abc2", 600)
  check(cmds[1]:find("timeout", 1, true) == nil, "sem o comando timeout no sistema: sobe sem ele")

end

return M
