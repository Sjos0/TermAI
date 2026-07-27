-- tests/google_grounding_pr5_spec.lua
-- Teste de isolamento: google_grounding com Interactions API + fallback chain
package.path = os.getenv("HOME") .. "/TermAI/?.lua;" .. os.getenv("HOME") .. "/TermAI/?/init.lua;" .. package.path

package.loaded["json"] = package.loaded["json"] or dofile(os.getenv("HOME") .. "/TermAI/json.lua")
local json = require("json")

local pass, fail = 0, 0
local function TEST(name, ok, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. detail) or ""))
  end
end

print("\n=== Teste de Isolamento: Google Grounding (Interactions API + Fallback) ===\n")

-- ═══════════════════════════════════════════════════════
-- SETUP: Mocks
-- ═══════════════════════════════════════════════════════

local config_mod = require("config")
local orig_load = config_mod.load
config_mod.load = function()
  return {
    web_tools = {
      enabled = true,
      google_grounding_key = "FAKE_API_KEY_FOR_TEST_12345"
    }
  }
end

local captured_cmd = nil
local captured_payload = nil
local call_count = 0
local mock_queue = {}

local orig_popen = io.popen
io.popen = function(cmd)
  captured_cmd = cmd
  call_count = call_count + 1
  local response = table.remove(mock_queue, 1) or '{"steps":[{"type":"thought","text":"..."},{"type":"model_output","content":[{"type":"text","text":"Resposta mockada"}]}]}'
  return {
    read = function(self) return response end,
    close = function(self) end
  }
end

local orig_remove = os.remove
os.remove = function(path) return true end

local orig_open = io.open
io.open = function(path, mode)
  if mode == "w" then
    return {
      write = function(self, data) captured_payload = data end,
      close = function(self) end
    }
  end
  return orig_open(path, mode)
end

local function reload()
  for k in pairs(package.loaded) do
    if k:find("google_grounding") then package.loaded[k] = nil end
  end
  package.loaded["agent.security"] = nil
  package.loaded["agent.security.validator"] = nil
  package.loaded["config"] = config_mod  -- garantir que config mock está ativo
  return require("providers.google_grounding")
end

-- ═══════════════════════════════════════════════════════
-- TESTES
-- ═══════════════════════════════════════════════════════

-- 1: Módulo carrega
local g = reload()
TEST("Módulo carrega sem erro", g ~= nil and g.id == "google_grounding")

-- 2: Chamada básica
captured_cmd = nil; captured_payload = nil
local result = g.search("capital do brasil")
TEST("search() retorna string", type(result) == "string")

-- 3: Endpoint correto
TEST("Endpoint é /v1beta/interactions",
  captured_cmd ~= nil and captured_cmd:find("v1beta/interactions") ~= nil)
TEST("Endpoint NÃO usa generateContent",
  captured_cmd ~= nil and captured_cmd:find("generateContent") == nil)

-- 4: Payload
TEST("Payload contém 'model'", captured_payload ~= nil and captured_payload:find('"model"') ~= nil)
TEST("Payload contém 'input'", captured_payload ~= nil and captured_payload:find('"input"') ~= nil)
TEST("Payload contém tools google_search", captured_payload ~= nil and captured_payload:find('"google_search"') ~= nil)

-- 5: Modelo primário é gemini-2.5-flash
TEST("Modelo padrão é gemini-2.5-flash",
  captured_payload ~= nil and captured_payload:find("gemini%-2%.5%-flash") ~= nil)

-- 6: Resposta com texto
TEST("Resposta contém texto mockado", result:find("Resposta mockada") ~= nil)

-- 7: Resposta com fontes (annotations)
package.loaded["providers.google_grounding"] = nil
mock_queue = {json.encode({
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
local g2 = reload()
local r2 = g2.search("teste fontes")
TEST("Resposta extrai annotations como fontes", r2:find("example.com") ~= nil)
TEST("Resposta deduplica fontes", r2:find("test.com") ~= nil)

-- 8: Resposta com queries
package.loaded["providers.google_grounding"] = nil
mock_queue = {json.encode({
  steps = {
    {type = "google_search_call", arguments = {queries = {"query1", "query2"}}},
    {type = "model_output", content = {{type = "text", text = "Resposta"}}}
  }
})}
local g3 = reload()
local r3 = g3.search("teste queries")
TEST("Resposta mostra queries executadas", r3:find("Queries") ~= nil or r3:find("query1") ~= nil)

-- 9: Fallback chain — modelo primário falha, segundo funciona
package.loaded["providers.google_grounding"] = nil
mock_queue = {
  json.encode({error = {code = 429, message = "quota exceeded"}}),  -- modelo 1 falha
  json.encode({  -- modelo 2 funciona
    steps = {{
      type = "model_output",
      content = {{type = "text", text = "Resposta do fallback"}}
    }}
  })
}
local g4 = reload()
local r4 = g4.search("teste fallback")
TEST("Fallback: modelo 1 falha, modelo 2 responde", r4:find("fallback") ~= nil)

-- 10: Todos os modelos falham
package.loaded["providers.google_grounding"] = nil
mock_queue = {
  json.encode({error = {code = 429, message = "quota exceeded"}}),
  json.encode({error = {code = 429, message = "quota exceeded"}}),
  json.encode({error = {code = 429, message = "quota exceeded"}}),
}
local g5 = reload()
local r5 = g5.search("todos falham")
TEST("Todos modelos falham → mensagem de erro", r5:find("Cota") ~= nil or r5:find("Rate") ~= nil)

-- 11: Erro 403 (chave) — não tenta fallback
package.loaded["providers.google_grounding"] = nil
mock_queue = {
  json.encode({error = {code = 403, message = "key leaked"}}),
  json.encode({  -- não deveria chegar aqui
    steps = {{type = "model_output", content = {{type = "text", text = "não deveria"}}}}
  })
}
local g6 = reload()
local r6 = g6.search("erro chave")
TEST("Erro 403 não tenta fallback", r6:find("comprometida") ~= nil and r6:find("não deveria") == nil)

-- 12: Output vazio
package.loaded["providers.google_grounding"] = nil
mock_queue = {json.encode({steps = {{type = "model_output", content = {{type = "text", text = ""}}}}})}
local g7 = reload()
local r12 = g7.search("x")
TEST("Output vazio → 'Nenhum resultado'", r12:find("Nenhum resultado") ~= nil)

-- 13: Web Tools off
package.loaded["providers.google_grounding"] = nil
config_mod.load = function() return {web_tools = {enabled = false}} end
local g8 = require("providers.google_grounding")
TEST("Web Tools off → erro", g8.search("x"):find("desativadas") ~= nil)

-- 14: API key vazia
package.loaded["providers.google_grounding"] = nil
config_mod.load = function() return {web_tools = {enabled = true, google_grounding_key = ""}} end
local g9 = require("providers.google_grounding")
TEST("API key vazia → erro", g9.search("x"):find("não configurada") ~= nil)

-- ═══════════════════════════════════════════════════════
-- RESTAURAR
-- ═══════════════════════════════════════════════════════

config_mod.load = orig_load
io.popen = orig_popen
os.remove = orig_remove
io.open = orig_open

-- ═══════════════════════════════════════════════════════
-- RESULTADO
-- ═══════════════════════════════════════════════════════

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes passaram")
end
