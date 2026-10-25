-- tests/loop_units_spec/xml_path.lua — parte do spec de agent/loop (ver tests/loop_units_spec.lua).
local harness = require("tests.helpers.harness")
local D = require("tests.loop_units_spec.dobles")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  sec("xml_path.handle")

  package.loaded["agent.loop.xml_path"] = nil
  local xp = require("agent.loop.xml_path")
  local r


  D.reset_ui_log()
  D.set_th("resposta final do agente", {}, nil, "")
  r = xp.handle({}, "resposta final do agente", "raciocínio", true, 2.0, 0, 2)
  T("xml final: action=return", r.action == "return")
  T("xml final: flush_done=false", r.flush_done == false)
  T("xml final: last_reasoning propagado", r.last_reasoning == "raciocínio")
  T("xml final: streamou display",
    #D.ui_log == 1 and D.ui_log[1].text == "resposta final do agente")
  T("xml final: elapsed propagado", r.elapsed == 2.0)

  D.reset_ui_log()
  D.set_th("arquivado [FLUSH_DONE]", {}, nil, "")
  r = xp.handle({}, "arquivado [FLUSH_DONE]", nil, true, 1, 0, 2)
  T("xml FLUSH_DONE sem tools: return+flush_done",
    r.action == "return" and r.flush_done == true)
  T("xml FLUSH_DONE sem tools: streamou sem tag",
    #D.ui_log == 1 and D.ui_log[1].text:find("FLUSH_DONE") == nil)
  T("xml FLUSH_DONE sem tools: last_reasoning vazio (nil→\"\")",
    r.last_reasoning == "")

  D.reset_ui_log()
  D.set_th("usando ferramenta", { { name = "Read" } }, nil, "resultado-tool")
  r = xp.handle({}, "usando ferramenta", "", true, 0.5, 0, 2)
  T("xml tools: action=continue", r.action == "continue")
  T("xml tools: iter_delta=1", r.iter_delta == 1)
  T("xml tools: cur_text=exec_result", r.cur_text == "resultado-tool")
  T("xml tools: cur_role=user", r.cur_role == "user")
  T("xml tools: streamou texto", #D.ui_log == 1 and D.ui_log[1].text == "usando ferramenta")

  D.set_th("", {}, "feedback prévio", "")
  r = xp.handle({}, "", "", true, 0, 0, 2)
  T("xml pre_feedback only: continue", r.action == "continue")
  T("xml pre_feedback only: iter_delta=0", r.iter_delta == 0)
  T("xml pre_feedback only: cur_text=feedback", r.cur_text == "feedback prévio")

  D.set_th("txt", { { name = "X" } }, "mais feedback", "out")
  r = xp.handle({}, "txt", "", true, 0, 0, 2)
  T("xml tools+feedback: cur_text concatenado",
    r.cur_text == "out\n\nmais feedback")

  D.set_th("ok [FLUSH_DONE]", { { name = "W" } }, nil, "wrote")
  r = xp.handle({}, "raw [FLUSH_DONE]", "", true, 0, 0, 2)
  T("xml tools+FLUSH_DONE: return flush_done",
    r.action == "return" and r.flush_done == true)

  D.reset_ui_log()
  D.set_th("", {}, nil, "")
  r = xp.handle({}, "", nil, true, 0, 0, 2)
  T("xml vazio: action=retry", r.action == "retry")
  T("xml vazio: vazio_count=1", r.vazio_count == 1)
  T("xml vazio: cur_role=user", r.cur_role == "user")
  T("xml vazio sem reasoning: mensagem genérica",
    r.cur_text:find("Continue de onde parou") ~= nil)

  D.set_th("[vazio]", {}, nil, "")
  r = xp.handle({}, "[vazio]", "estava pensando em X", true, 0, 0, 2)
  T("xml [vazio]+reasoning: mensagem de raciocínio",
    r.action == "retry" and r.cur_text:find("não emitiu resposta") ~= nil)

  D.reset_ui_log()
  D.set_th("Vou abrir o arquivo:", {}, nil, "")
  r = xp.handle({}, "Vou abrir o arquivo:", "", true, 0, 0, 2)
  T("xml unfulfilled: action=retry", r.action == "retry")
  T("xml unfulfilled: mensagem anúncio",
    r.cur_text:find("anunciou uma ação") ~= nil)
  T("xml unfulfilled: streamou o anúncio",
    #D.ui_log == 1 and D.ui_log[1].text == "Vou abrir o arquivo:")

  D.reset_ui_log()
  D.set_th("", {}, nil, "")
  r = xp.handle({}, "", "", true, 0, 2, 2)
  T("xml retries esgotados: action=return", r.action == "return")
  T("xml retries esgotados: flush_done=false", r.flush_done == false)

  D.set_th("fazendo:", {}, nil, "")
  r = xp.handle({}, "fazendo:", "", true, 0, 2, 2)
  T("xml unfulfilled esgotado: return", r.action == "return")
  T("xml unfulfilled esgotado: streamou display",
    #D.ui_log >= 1 and D.ui_log[#D.ui_log].text == "fazendo:")

  D.set_th("", {}, nil, "")
  r = xp.handle({}, "[ERRO provider down]", "", true, 0, 0, 2)
  T("xml [ERRO]: não é retry (return)", r.action == "return")

  D.set_th("vou:", {}, nil, "")
  r = xp.handle({}, "[ERRO algo] vou:", "", true, 0, 0, 2)
  T("xml [ERRO]+unfulfilled: return (sem retry)", r.action == "return")

  D.set_th("[FLUSH_DONE]", {}, nil, "")
  r = xp.handle({}, "[FLUSH_DONE]", "", true, 0, 0, 2)
  T("xml resp FLUSH_DONE display vazio: return flush_done",
    r.action == "return" and r.flush_done == true)

  D.set_th("ok", {}, nil, "")
  r = xp.handle({}, "ok", "rr", true, 1, 0, 2)
  T("xml return contrato: campos obrigatórios",
    r.action == "return"
    and r.resp ~= nil
    and r.elapsed ~= nil
    and r.flush_done ~= nil
    and r.is_overflow == false
    and r.stream_complete ~= nil
    and r.last_reasoning ~= nil)

  D.set_th("t", { { name = "A" } }, nil, "x")
  r = xp.handle({}, "t", "", true, 0, 0, 2)
  T("xml continue contrato: campos obrigatórios",
    r.action == "continue"
    and r.iter_delta ~= nil
    and r.cur_text ~= nil
    and r.cur_role == "user"
    and r.last_reasoning == "")

  D.set_th("", {}, nil, "")
  r = xp.handle({}, "", "", true, 0, 0, 2)
  T("xml retry contrato: campos obrigatórios",
    r.action == "retry"
    and type(r.vazio_count) == "number"
    and r.cur_text ~= nil
    and r.cur_role == "user")

end

return M
