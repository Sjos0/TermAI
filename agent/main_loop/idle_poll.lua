-- idle_poll.lua — callback de idle do input: tick do scheduler e bloco de subagentes.
-- Interface: M.make_on_idle(ctx, prompt_text) → function(buffer_empty) → boolean?
local scheduler = require("tools.subagents.scheduler")
local subagents = require("tools.subagents")
local sub_block = require("ui.subagent_block")

local M = {}

function M.make_on_idle(ctx, prompt_text)
  local last_tick = 0
  return function(buffer_empty)
    if os.time() - last_tick >= 2 then
      last_tick = os.time()
      pcall(scheduler.tick, ctx.cfg)
    end
    sub_block.flush(ctx.agent_id, buffer_empty, prompt_text)
    return buffer_empty and subagents.has_pending(ctx)
  end
end

return M
