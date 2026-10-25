-- tests/loop_units_spec/response_utils.lua — parte do spec de agent/loop (ver tests/loop_units_spec.lua).
local harness = require("tests.helpers.harness")
local D = require("tests.loop_units_spec.dobles")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  sec("response_utils.strip_flush_tag")

  local ru = require("agent.loop.response_utils")

  T("nil → string vazia", ru.strip_flush_tag(nil) == "")
  T("string vazia → vazia", ru.strip_flush_tag("") == "")
  T("só [FLUSH_DONE] → vazia", ru.strip_flush_tag("[FLUSH_DONE]") == "")
  T("texto + tag → texto limpo",
    ru.strip_flush_tag("olá [FLUSH_DONE] mundo") == "olá  mundo"
    or ru.strip_flush_tag("olá [FLUSH_DONE] mundo") == "olá mundo")
  -- gsub remove a tag; espaços internos ficam; trim só nas bordas
  local mid = ru.strip_flush_tag("olá [FLUSH_DONE] mundo")
  T("remove tag mantendo texto ao redor", mid:find("olá") ~= nil and mid:find("mundo") ~= nil and mid:find("FLUSH_DONE") == nil)
  T("trim bordas",
    ru.strip_flush_tag("  hello  ") == "hello")
  T("tag no início",
    ru.strip_flush_tag("[FLUSH_DONE] pronto") == "pronto")
  T("tag no fim",
    ru.strip_flush_tag("pronto [FLUSH_DONE]") == "pronto")
  T("múltiplas tags",
    ru.strip_flush_tag("[FLUSH_DONE] a [FLUSH_DONE] b") == "a  b"
    or (ru.strip_flush_tag("[FLUSH_DONE] a [FLUSH_DONE] b"):find("a") ~= nil
        and ru.strip_flush_tag("[FLUSH_DONE] a [FLUSH_DONE] b"):find("FLUSH") == nil))
  T("não confunde tag parecida",
    ru.strip_flush_tag("[FLUSH_DONE_NOT]") == "[FLUSH_DONE_NOT]")

  sec("response_utils.is_unfulfilled_intent")

  T("nil → false", ru.is_unfulfilled_intent(nil) == false)
  T("vazio → false", ru.is_unfulfilled_intent("") == false)
  T("termina em : → true", ru.is_unfulfilled_intent("Vou ler o arquivo:") == true)
  T("só : → true", ru.is_unfulfilled_intent(":") == true)
  T("espaços após : são trimados → true",
    ru.is_unfulfilled_intent("ação:   ") == true)
  T("texto normal → false", ru.is_unfulfilled_intent("Resposta completa.") == false)
  T("termina em ? → false", ru.is_unfulfilled_intent("Posso ajudar?") == false)
  T("whitespace puro → false",
    ru.is_unfulfilled_intent("   \n\t  ") == false)
  T(": no meio → false", ru.is_unfulfilled_intent("a:b") == false)

end

return M
