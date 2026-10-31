-- tests/web_search_fallback_spec.lua
-- #338 — Regressão do lote 1 do #325 (PR #336).
--
-- Causa: tools/web.lua:42 reconhecia como falha apenas o formato antigo ("^❌" e
-- "🔍 Nenhum resultado"), mas os provedores passaram a emitir o formato novo
-- ("[FAIL] ..." e "[SEARCH] Nenhum resultado ...") desde o lote 1.
-- Efeito: com fallback_enabled = true, a falha do 1º provedor era DEVOLVIDA ao
-- usuário como se fosse resultado e o 2º provedor nunca era chamado.
--
-- Este spec é de integração: registra a ferramenta pelo caminho real (M.register,
-- como o runtime faz), troca config e providers em package.loaded e observa
-- qual provedor foi efetivamente chamado.
--
-- NOTA (#425/D6): os casos do formato antigo ("❌"/"🔍") existem só enquanto o
-- projeto mantém compatibilidade de leitura com os dois formatos. Quando o
-- NOTA (passo D6 do plano): os casos do formato antigo ("❌"/"🔍") existem só
-- enquanto o projeto mantém compatibilidade de leitura com os dois formatos.
-- Quando o formato antigo for removido dos produtores, apagar os casos marcados
-- como [legado] abaixo.

local web = require("tools.web")

local pass, fail = 0, 0
local function TEST(name, ok, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. detail) or ""))
  end
end

local OK_DDG    = '[SEARCH] **Resultado (DuckDuckGo):** "lua"' .. "\n• https://lua.org"
local OK_TAVILY = '[SEARCH] **Resultado (Tavily Search):** "lua"' .. "\n• https://tavily.example"

local FAIL_DDG_NOVO = "[FAIL] Busca bloqueada temporariamente pelo DuckDuckGo (Bot Challenge)."
local FAIL_DDG_LEGADO = "❌ DDG bloqueado (CAPTCHA)"
local VAZIO_NOVO = "[SEARCH] Nenhum resultado para: lua"
local VAZIO_LEGADO = "🔍 Nenhum resultado"

-- montar(resposta_ddg, resposta_tavily) -> fn, chamadas
-- Instala config e providers falsos, registra web_search e devolve o handler
-- capturado, mais uma lista com a ordem dos provedores chamados.
local function montar(resposta_ddg, resposta_tavily)
  local chamadas = {}
  local cfg = {
    web_tools = {
      fallback_enabled = true,
      provider = "duckduckgo_search",
      fallback_chain = { "duckduckgo_search", "tavily_search" },
    },
  }
  package.loaded["config"] = { load = function() return cfg end }
  package.loaded["providers.duckduckgo_search"] = {
    id = "duckduckgo_search",
    search = function(_q) chamadas[#chamadas + 1] = "duckduckgo_search"; return resposta_ddg end,
  }
  package.loaded["providers.tavily_search"] = {
    id = "tavily_search",
    search = function(_q) chamadas[#chamadas + 1] = "tavily_search"; return resposta_tavily end,
  }
  local fn
  web.register({ register = function(_nome, _desc, f) fn = f end })
  return fn, chamadas
end

local function cadeia(chamadas)
  return "{" .. table.concat(chamadas, " -> ") .. "}"
end

print("\n=== #338: fallback do web_search com o formato novo de erro ([FAIL]/[SEARCH]) ===\n")

-- 1. CASO DA ISSUE: provedor 1 responde [FAIL] -> deve cair no provedor 2.
local fn, chamadas = montar(FAIL_DDG_NOVO, OK_TAVILY)
local res = fn({ query = "lua" })
TEST("[FAIL] no 1º provedor aciona o fallback",
  chamadas[2] == "tavily_search", "cadeia = " .. cadeia(chamadas))
TEST("[FAIL] no 1º provedor: resultado final é o do 2º provedor",
  res == OK_TAVILY, "res = " .. tostring(res))

-- 2. [legado] O mesmo com o formato antigo, que já funcionava.
local fn2, chamadas2 = montar(FAIL_DDG_LEGADO, OK_TAVILY)
local res2 = fn2({ query = "lua" })
TEST("[legado] ❌ no 1º provedor continua acionando o fallback",
  chamadas2[2] == "tavily_search", "cadeia = " .. cadeia(chamadas2))
TEST("[legado] ❌ no 1º provedor: resultado final é o do 2º provedor",
  res2 == OK_TAVILY, "res = " .. tostring(res2))

-- 3. Formato novo de "nenhum resultado" -> também deve cair no próximo provedor.
local fn3, chamadas3 = montar(VAZIO_NOVO, OK_TAVILY)
local res3 = fn3({ query = "lua" })
TEST("[SEARCH] Nenhum resultado aciona o fallback",
  chamadas3[2] == "tavily_search", "cadeia = " .. cadeia(chamadas3))
TEST("[SEARCH] Nenhum resultado: resultado final é o do 2º provedor",
  res3 == OK_TAVILY, "res = " .. tostring(res3))

-- 4. [legado] "🔍 Nenhum resultado" continua caindo no próximo provedor.
local fn4, chamadas4 = montar(VAZIO_LEGADO, OK_TAVILY)
local res4 = fn4({ query = "lua" })
TEST("[legado] 🔍 Nenhum resultado aciona o fallback",
  chamadas4[2] == "tavily_search", "cadeia = " .. cadeia(chamadas4))
TEST("[legado] 🔍 Nenhum resultado: resultado final é o do 2º provedor",
  res4 == OK_TAVILY, "res = " .. tostring(res4))

-- 5. Não-regressão: sucesso no 1º provedor não chama o 2º.
local fn5, chamadas5 = montar(OK_DDG, OK_TAVILY)
local res5 = fn5({ query = "lua" })
TEST("sucesso no 1º provedor não aciona o fallback",
  #chamadas5 == 1, "cadeia = " .. cadeia(chamadas5))
TEST("sucesso no 1º provedor devolve o resultado do 1º provedor",
  res5 == OK_DDG, "res = " .. tostring(res5))

-- 6. Todos falham -> devolve a última falha (do provedor final), não a primeira.
local fn6, chamadas6 = montar(FAIL_DDG_NOVO, "[FAIL] Erro Tavily: 401")
local res6 = fn6({ query = "lua" })
TEST("todos falham: os dois provedores são tentados",
  #chamadas6 == 2, "cadeia = " .. cadeia(chamadas6))
TEST("todos falham: devolve a falha do último provedor",
  res6 == "[FAIL] Erro Tavily: 401", "res = " .. tostring(res6))

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  os.exit(1)
end
