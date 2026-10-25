-- agent/session_cmds/nucleo_1.lua — helpers internos: rebuild_ctx.
return function(M)
  local P = require("agent.session_cmds.nucleo")(M)
  local session, prompt_module, tools = P.session, P.prompt_module, P.tools


  local function rebuild_ctx(ctx)
    ctx.msgs   = {{role = "system",
                   content = prompt_module.build(ctx.workspace, tools, session.current())}}
    ctx.tokens = 0
  end
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.rebuild_ctx = rebuild_ctx
  return N
end
