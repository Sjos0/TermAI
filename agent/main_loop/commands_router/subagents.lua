-- agent/main_loop/commands_router/subagents.lua — /subagents list | info <id> | log <id> [n] | kill <id>.
local control   = require("tools.subagents.control")
local scheduler = require("tools.subagents.scheduler")
local M = {}

local USAGE = "Uso: /subagents [list | info <id> | log <id> [n] | kill <id>]"

-- Retorna {action="continue"} quando o comando casa; {} caso contrário.
function M.route(input, ctx, flush_msgs_start)
  if input ~= "/subagents" and not input:match("^/subagents%s") then return {} end

  -- Atualiza o estado antes de mostrar (fila, processos mortos, timeouts).
  pcall(scheduler.tick, ctx and ctx.cfg)

  local rest = (input:gsub("^/subagents%s*", ""))
  local sub, id, extra = rest:match("^(%S*)%s*(%S*)%s*(%S*)")
  local out
  if sub == "" or sub == "list" then
    out = control.listar({})
  elseif sub == "info" then
    out = id ~= "" and control.info({ runId = id }) or USAGE
  elseif sub == "log" then
    out = id ~= "" and control.log({ runId = id, linhas = tonumber(extra) }) or USAGE
  elseif sub == "gc" then
    local n = require("tools.subagents.cleanup").sweep()
    io.write("\27[38;5;114m✓\27[0m " .. n .. " run(s) antigo(s) removido(s) (guardados: 50 runs ou 7 dias)\n\n")
  elseif sub == "kill" then
    out = id ~= "" and control.matar({ runId = id }) or USAGE
  else
    out = USAGE
  end
  io.write(out .. "\n")
  io.flush()
  return { action = "continue", flush_msgs_start = flush_msgs_start }
end

return M
