-- tests/google_grounding_units_spec.lua
-- Testes unitários dos submódulos extraídos em providers/google_grounding/
-- Origem: Issue #27 / PR #37 (refactor monólito → fachada + submódulos)
-- Objetivo: trava de regressão para error_classifier, response_extractor,
--           formatter e constants — módulos de responsabilidade única
--           agora isoláveis sem I/O de rede.
--
-- "E se isso mudar?": qualquer alteração futura em classificação de erro,
-- extração de steps/annotations ou formatação de saída deve falhar aqui
-- antes de chegar ao usuário.

package.path = "./?.lua;./?/init.lua;" .. package.path

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
  end
end

local function sec(title)
  print("\n=== " .. title .. " ===")
end

print("\n=== Unit tests: google_grounding submodules (Issue #27 / PR #37) ===\n")

-- ────────────────────────────────────────────────────────────
-- constants
-- ────────────────────────────────────────────────────────────
sec("constants")

local constants = require("providers.google_grounding.constants")

T("MODELS é table com ≥1 modelo", type(constants.MODELS) == "table" and #constants.MODELS >= 1)
T("Primeiro modelo é gemini-2.5-flash", constants.MODELS[1] == "gemini-2.5-flash")
T("INTERACTIONS_URL aponta para /v1beta/interactions",
  type(constants.INTERACTIONS_URL) == "string"
  and constants.INTERACTIONS_URL:find("v1beta/interactions") ~= nil
  and constants.INTERACTIONS_URL:find("generateContent") == nil)

-- ────────────────────────────────────────────────────────────
-- error_classifier
-- ────────────────────────────────────────────────────────────
sec("error_classifier.classify_error")

local ec = require("providers.google_grounding.error_classifier")

T("sem data.error → mensagem genérica",
  ec.classify_error({}) == "❌ Erro desconhecido do Google.")

local r429q = ec.classify_error({
  error = { code = 429, message = "quota exceeded, resource_exhausted, retry in 12.5s" }
})
T("429 + quota → Cota esgotada + retry",
  r429q:find("Cota") ~= nil and r429q:find("Tente em 12.5s") ~= nil)

local r429 = ec.classify_error({
  error = { code = 429, message = "too_many_requests, retry in 3s" }
})
T("429 genérico → Rate limit + retry",
  r429:find("Rate limit") ~= nil and r429:find("Tente em 3s") ~= nil)

local r403l = ec.classify_error({
  error = { code = 403, message = "API key leaked" }
})
T("403 leaked → chave comprometida + link aistudio",
  r403l:find("comprometida") ~= nil and r403l:find("aistudio.google.com") ~= nil)

local r403 = ec.classify_error({
  error = { code = 403, message = "permission denied" }
})
T("403 genérico → chave inválida",
  r403:find("inválida") ~= nil or r403:find("permissão") ~= nil)

local r400 = ec.classify_error({
  error = { code = 400, message = "bad request body" }
})
T("400 → requisição inválida",
  r400:find("inválida") ~= nil and r400:find("bad request body") ~= nil)

local r500 = ec.classify_error({
  error = { code = 500, message = "internal" }
})
T("código desconhecido → Erro Google [code]",
  r500:find("Erro Google %[500%]") ~= nil and r500:find("internal") ~= nil)

-- ────────────────────────────────────────────────────────────
-- response_extractor
-- ────────────────────────────────────────────────────────────
sec("response_extractor.extract_response")

local re = require("providers.google_grounding.response_extractor")

local text1, src1, q1 = re.extract_response({
  steps = {
    { type = "thought", text = "ignorar" },
    { type = "google_search_call", arguments = { queries = { "q1", "q2" } } },
    {
      type = "model_output",
      content = {
        {
          type = "text",
          text = "Texto final",
          annotations = {
            { type = "url_citation", url = "https://a.example", title = "A", start_index = 0, end_index = 5 },
            { type = "url_citation", url = "https://b.example", title = "B" },
          },
        },
      },
    },
  },
})
T("extrai texto de model_output", text1 == "Texto final")
T("extrai queries de google_search_call", #q1 == 2 and q1[1] == "q1" and q1[2] == "q2")
T("extrai fontes de annotations", #src1 == 2 and src1[1].url == "https://a.example" and src1[2].title == "B")

local text2, src2, q2 = re.extract_response({
  output_text = "via output_text",
  steps = {},
})
T("fallback output_text quando presente", text2 == "via output_text")

local text3, src3 = re.extract_response({
  grounding_metadata = {
    grounding_chunks = {
      { web = { uri = "https://old.example", title = "Old" } },
    },
  },
})
T("fallback grounding_metadata.snake_case", #src3 == 1 and src3[1].url == "https://old.example")

local text4, src4 = re.extract_response({
  grounding_metadata = {
    groundingChunks = {
      { web = { uri = "https://camel.example", title = "Camel" } },
    },
  },
})
T("fallback grounding_metadata.camelCase", #src4 == 1 and src4[1].url == "https://camel.example")

local text5, src5, q5 = re.extract_response({})
T("data vazio → strings/tabelas vazias", text5 == "" and #src5 == 0 and #q5 == 0)

-- Concatena múltiplos blocos de texto
local text6 = select(1, re.extract_response({
  steps = {
    {
      type = "model_output",
      content = {
        { type = "text", text = "Parte1" },
        { type = "text", text = "Parte2" },
      },
    },
  },
}))
T("concatena múltiplos blocos text", text6 == "Parte1Parte2")

-- ────────────────────────────────────────────────────────────
-- formatter
-- ────────────────────────────────────────────────────────────
sec("formatter.format_result")

local fmt = require("providers.google_grounding.formatter")

local out1 = fmt.format_result("minha query", "corpo da resposta", {}, {})
T("formato básico contém Resultado e query",
  out1:find("Resultado") ~= nil and out1:find("minha query") ~= nil and out1:find("corpo da resposta") ~= nil)

local out2 = fmt.format_result("q", "txt", {
  { url = "https://x.com", title = "X" },
  { url = "https://x.com", title = "X dup" }, -- dedup
  { url = "https://y.com", title = "Y" },
}, { "qa", "qb" })
T("inclui seção Queries", out2:find("Queries") ~= nil and out2:find("qa") ~= nil)
T("inclui seção Fontes", out2:find("Fontes") ~= nil)
T("deduplica fontes pelo url", out2:find("X dup") == nil)
T("numera fontes", out2:find("1%. X") ~= nil and out2:find("2%. Y") ~= nil)

local out3 = fmt.format_result("só texto", "ok", {}, {})
T("sem fontes/queries não inventa seções",
  out3:find("Fontes") == nil and out3:find("Queries") == nil)

-- ────────────────────────────────────────────────────────────
-- RELATÓRIO
-- ────────────────────────────────────────────────────────────
print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes unitários dos submódulos passaram")
end
