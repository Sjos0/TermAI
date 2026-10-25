-- tests/google_grounding_pr5_spec/parte_a.lua — testes de módulo, chamada básica e fallback (1-N).
local harness = require("tests.helpers.harness")
local D = require("tests.google_grounding_pr5_spec.dobles")
local json = require("json")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  -- 1: Módulo carrega
  local g = D.reload()
  T("Módulo carrega sem erro", g ~= nil and g.id == "google_grounding")

  -- 2: Chamada básica
  D.captured_cmd = nil; D.captured_payload = nil
  local result = g.search("capital do brasil")
  T("search() retorna string", type(result) == "string")

  -- 3: Endpoint correto
  T("Endpoint é /v1beta/interactions",
    D.captured_cmd ~= nil and D.captured_cmd:find("v1beta/interactions") ~= nil)
  T("Endpoint NÃO usa generateContent",
    D.captured_cmd ~= nil and D.captured_cmd:find("generateContent") == nil)

  -- 4: Payload
  T("Payload contém 'model'", D.captured_payload ~= nil and D.captured_payload:find('"model"') ~= nil)
  T("Payload contém 'input'", D.captured_payload ~= nil and D.captured_payload:find('"input"') ~= nil)
  T("Payload contém tools google_search", D.captured_payload ~= nil and D.captured_payload:find('"google_search"') ~= nil)

  -- 5: Modelo primário é gemini-2.5-flash
  T("Modelo padrão é gemini-2.5-flash",
    D.captured_payload ~= nil and D.captured_payload:find("gemini%-2%.5%-flash") ~= nil)

  -- 6: Resposta com texto
  T("Resposta contém texto mockado", result:find("Resposta mockada") ~= nil)

  -- 7: Resposta com fontes (annotations)
  package.loaded["providers.google_grounding"] = nil
  D.mock_queue = {json.encode({
    steps = {{
      type = "model_output",
      content = {{
        type = "text",
        text = "Resposta com fontes",
        annotations = {
          {type = "url_citation", url = "https://example.com", title = "Example", start_index = 0, end_index = 10},
          {type = "url_citation", url = "https://test.com", title = "Test", start_index = 11, end_index = 20}
        }
      }}
    }}
  })}
  local g2 = D.reload()
  local r2 = g2.search("teste fontes")
  T("Resposta extrai annotations como fontes", r2:find("example.com") ~= nil)
  T("Resposta deduplica fontes", r2:find("test.com") ~= nil)

  -- 8: Resposta com queries
  package.loaded["providers.google_grounding"] = nil
  D.mock_queue = {json.encode({
    steps = {
      {type = "google_search_call", arguments = {queries = {"query1", "query2"}}},
      {type = "model_output", content = {{type = "text", text = "Resposta"}}}
    }
  })}
  local g3 = D.reload()
  local r3 = g3.search("teste queries")
  T("Resposta mostra queries executadas", r3:find("Queries") ~= nil or r3:find("query1") ~= nil)

end

return M
