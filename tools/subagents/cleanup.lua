-- tools/subagents/cleanup.lua — Apaga o run depois de anunciado, salvo se cleanup == "keep".
local registry  = require("tools.subagents.registry")
local scheduler = require("tools.subagents.scheduler")
local M = {}

function M.sweep()
  local n = 0
  for _, rec in ipairs(registry.list()) do
    if scheduler.is_terminal(rec) and rec.announce_consumed and rec.cleanup ~= "keep" then
      registry.remove(rec.runId)
      n = n + 1
    end
  end
  return n
end

return M
