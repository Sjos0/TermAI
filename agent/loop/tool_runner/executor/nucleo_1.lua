-- agent/loop/tool_runner/executor/nucleo_1.lua — helpers internos: ui_start, ui_end, get_wall_time, is_read_call.
return function(M)
  local P = require("agent.loop.tool_runner.executor.nucleo")(M)
  local ui, tools_mod, subagent_ui = P.ui, P.tools_mod, P.subagent_ui



  -- Clone não desenha corpo de ferramenta: manda o nome para o bloco aninhado.
  local function ui_start(ctx, disp)
    if ctx and ctx.is_subagent then
      if ctx.run_id then require("tools.subagents.events").append(ctx.run_id, "tool", disp) end
      return subagent_ui.child_start(disp)
    end
    return ui.tool_start(disp)
  end


  local function ui_end(ctx, disp, out, ok)
    if ctx and ctx.is_subagent then return subagent_ui.child_end() end
    return ui.tool_end(disp, out, ok)
  end


  local function get_wall_time()
    local f = io.open("/proc/uptime", "r")
    if not f then return os.time() end
    local val = f:read("*n")
    f:close()
    return val or os.time()
  end


  local function is_read_call(tc)
    return tc.name == "Read" and tools_mod.registry[tc.name] ~= nil
  end
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.ui_start = ui_start
  N.ui_end = ui_end
  N.get_wall_time = get_wall_time
  N.is_read_call = is_read_call
  return N
end
