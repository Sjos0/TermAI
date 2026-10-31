-- tests/web_search_fallback_spec.lua
-- #338 — Regressão do lote 1 do #325 (PR #336). #352 (D6) — fim do formato antigo.
--
-- Causa: tools/web.lua:42 reconhecia como falha apenas o formato antigo ("^❌" e
-- "🔍 Nenhum resultado"), mas os provedores passaram a emitir o formato novo
-- ("[FAIL] ..." e "[SEARCH] Nenhum resultado ...") desde o lote 1.
-- Efeito: com fallback_enabled = true, a falha do 1o provedor era DEVOLVIDA ao
-- usuário como se fosse resultado e o 2o provedor nunca era chamado.
--
-- Este spec é de integração: registra a ferramenta pelo caminho real (M.register,
-- como o runtime faz), troca config e providers em package.loaded e observa
-- qual provedor foi efetivamente chamado.
--
-- NOTA (#352/D6): o formato antigo saiu dos produtores e do helper, então os casos
-- [legado] que o exercitavam foram apagados. A partir daqui só o formato novo é
-- testado; a ausência do símbolo nos diretórios de produção é travada por
-- tests/status_sem_simbolo_spec.lua.

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

local FAIL_DDG = "[FAIL] Busca bloqueada temporariamente pelo DuckDuckGo (Bot Challenge)."
local VAZIO    = "[SEARCH] Nenhum resultado para: lua"

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
local fn, chamadas = montar(FAIL_DDG, OK_TAVILY)
local res = fn({ query = "lua" })
TEST("[FAIL] no 1o provedor aciona o fallback",
  chamadas[2] == "tavily_search", "cadeia = " .. cadeia(chamadas))
TEST("[FAIL] no 1o provedor: resultado final é o do 2o provedor",
  res == OK_TAVILY, "res = " .. tostring(res))

-- 2. Formato novo de "nenhum resultado" -> também deve cair no próximo provedor.
local fn2, chamadas2 = montar(VAZIO, OK_TAVILY)
local res2 = fn2({ query = "lua" })
TEST("[SEARCH] Nenhum resultado aciona o fallback",
  chamadas2[2] == "tavily_search", "cadeia = " .. cadeia(chamadas2))
TEST("[SEARCH] Nenhum resultado: resultado final é o do 2o provedor",
  res2 == OK_TAVILY, "res = " .. tostring(res2))

-- 3. Não-regressão: sucesso no 1o provedor não chama o 2o.
local fn3, chamadas3 = montar(OK_DDG, OK_TAVILY)
local res3 = fn3({ query = "lua" })
TEST("sucesso no 1o provedor não aciona o fallback",
  #chamadas3 == 1, "cadeia = " .. cadeia(chamadas3))
TEST("sucesso no 1o provedor devolve o resultado do 1o provedor",
  res3 == OK_DDG, "res = " .. tostring(res3))

-- 4. Todos falham -> devolve a última falha (do provedor final), não a primeira.
local fn4, chamadas4 = montar(FAIL_DDG, "[FAIL] Erro Tavily: 401")
local res4 = fn4({ query = "lua" })
TEST("todos falham: os dois provedores são tentados",
  #chamadas4 == 2, "cadeia = " .. cadeia(chamadas4))
TEST("todos falham: devolve a falha do último provedor",
  res4 == "[FAIL] Erro Tavily: 401", "res = " .. tostring(res4))

print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  os.exit(1)
end
