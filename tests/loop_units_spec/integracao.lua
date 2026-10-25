-- tests/loop_units_spec/integracao.lua — parte do spec de agent/loop (ver tests/loop_units_spec.lua).
local harness = require("tests.helpers.harness")
local D = require("tests.loop_units_spec.dobles")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  sec("integração leve response_utils ↔ paths")

  D.reset_ui_log()
  package.loaded["agent.loop.tool_runner"].run_batch = function() end
  package.loaded["agent.loop.json_path"] = nil
  local jp = require("agent.loop.json_path")
  jp.handle({}, "msg [FLUSH_DONE]", { { name = "Z" } }, true, 0)
  T("integração json: stream recebe texto já stripped",
    #D.ui_log == 1 and D.ui_log[1].text:find("FLUSH_DONE") == nil and D.ui_log[1].text:find("msg") ~= nil)

  D.set_th("Próximo passo:", {}, nil, "")
  package.loaded["agent.loop.xml_path"] = nil
  local xp = require("agent.loop.xml_path")
  local r = xp.handle({}, "Próximo passo:", "", true, 0, 0, 1)
  T("integração xml: unfulfilled detectado via response_utils",
    r.action == "retry" and r.cur_text:find("anunciou uma ação") ~= nil)

end

return M
