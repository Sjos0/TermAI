-- tests/google_grounding_pr5_spec/parte_b.lua — demais casos de resposta, erro e formato.
local harness = require("tests.helpers.harness")
local D = require("tests.google_grounding_pr5_spec.dobles")
local json = require("json")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  -- 9: Fallback chain — modelo primário falha, segundo funciona
  package.loaded["providers.google_grounding"] = nil
  D.mock_queue = {
    json.encode({error = {code = 429, message = "quota exceeded"}}),  -- modelo 1 falha
    json.encode({  -- modelo 2 funciona
      steps = {{
        type = "model_output",
        content = {{type = "text", text = "Resposta do fallback"}}
      }}
    })
  }
  local g4 = D.reload()
  local r4 = g4.search("teste fallback")
  T("Fallback: modelo 1 falha, modelo 2 responde", r4:find("fallback") ~= nil)

  -- 10: Todos os modelos falham
  package.loaded["providers.google_grounding"] = nil
  D.mock_queue = {
    json.encode({error = {code = 429, message = "quota exceeded"}}),
    json.encode({error = {code = 429, message = "quota exceeded"}}),
    json.encode({error = {code = 429, message = "quota exceeded"}}),
  }
  local g5 = D.reload()
  local r5 = g5.search("todos falham")
  T("Todos modelos falham → mensagem de erro", r5:find("Cota") ~= nil or r5:find("Rate") ~= nil)

  -- 11: Erro 403 (chave) — não tenta fallback
  package.loaded["providers.google_grounding"] = nil
  D.mock_queue = {
    json.encode({error = {code = 403, message = "key leaked"}}),
    json.encode({  -- não deveria chegar aqui
      steps = {{type = "model_output", content = {{type = "text", text = "não deveria"}}}}
    })
  }
  local g6 = D.reload()
  local r6 = g6.search("erro chave")
  T("Erro 403 não tenta fallback", r6:find("comprometida") ~= nil and r6:find("não deveria") == nil)

  -- 12: Output vazio
  package.loaded["providers.google_grounding"] = nil
  D.mock_queue = {json.encode({steps = {{type = "model_output", content = {{type = "text", text = ""}}}}})}
  local g7 = D.reload()
  local r12 = g7.search("x")
  T("Output vazio → 'Nenhum resultado'", r12:find("Nenhum resultado") ~= nil)

  -- 13: Web Tools off
  package.loaded["providers.google_grounding"] = nil
  D.config_mod.load = function() return {web_tools = {enabled = false}} end
  local g8 = require("providers.google_grounding")
  T("Web Tools off → erro", g8.search("x"):find("desativadas") ~= nil)

  -- 14: API key vazia
  package.loaded["providers.google_grounding"] = nil
  D.config_mod.load = function() return {web_tools = {enabled = true, google_grounding_key = ""}} end
  local g9 = require("providers.google_grounding")
  T("API key vazia → erro", g9.search("x"):find("não configurada") ~= nil)
end

return M
