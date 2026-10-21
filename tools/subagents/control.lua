-- tools/subagents/control.lua — Comandos de controle: listar, ver detalhes, log e matar um run.
local registry  = require("tools.subagents.registry")
local scheduler = require("tools.subagents.scheduler")
local launcher  = require("tools.subagents.launcher")
local events    = require("tools.subagents.events")
local json      = require("json")
local M = {}

function M.listar(args)
  args = type(args) == "table" and args or {}
  local lines = {}
  for _, r in ipairs(registry.list()) do
    if not args.status or args.status == r.status then
      lines[#lines + 1] = string.format("%s | %s | %s | agente=%s", r.runId, r.status,
        tostring(r.kind), tostring(r.agentId))
    end
  end
  if #lines == 0 then return "Nenhum subagente." end
  return table.concat(lines, "\n")
end

function M.info(args)
  local r = registry.load(args.runId)
  if not r then return "❌ run não encontrado: " .. tostring(args.runId) end
  return json.encode(r)
end

function M.log(args)
  local lines = events.tail(args.runId, tonumber(args.linhas) or 20)
  if #lines == 0 then return "Sem eventos para " .. tostring(args.runId) end
  return table.concat(lines, "\n")
end

function M.matar(args)
  local r = registry.load(args.runId)
  if not r then return "❌ run não encontrado: " .. tostring(args.runId) end
  if scheduler.is_terminal(r) then return "Run já terminado: " .. r.status end
  launcher.kill(r.pid)
  r.status, r.error, r.finished_at = "killed", "morto pelo usuário", os.time()
  r.announce_pending = true
  registry.save(r)
  return "✓ " .. r.runId .. " encerrado."
end

return M
