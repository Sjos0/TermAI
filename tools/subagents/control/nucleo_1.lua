-- tools/subagents/control/nucleo_1.lua — helpers internos: count_tools, owned_by.
return function(M)
  local P = require("tools.subagents.control.nucleo")(M)
  local registry, events = P.registry, P.events


  local function count_tools(run_id)
    local f = io.open(registry.dir(run_id) .. "/events.jsonl", "r")
    if not f then return 0 end
    local n = 0
    for line in f:lines() do
      if line:find('"kind"%s*:%s*"tool"') then n = n + 1 end
    end
    f:close()
    return n
  end


  -- Dono de um run: o agente que o criou (nível 0) ou o run que o criou (aninhado).
  local function owned_by(rec, ctx)
    if ctx and ctx.run_id then return rec.parent_run == ctx.run_id end
    return rec.parent_run == nil and rec.parent_agent == ((ctx and ctx.agent_id) or "main")
  end
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.count_tools = count_tools
  N.owned_by = owned_by
  return N
end
