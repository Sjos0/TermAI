-- tests/google_grounding_units_spec/02_response_extractor_extract.lua — parte de google_grounding_units_spec.lua (ver fachada).
local harness = require("tests.helpers.harness")

local M = {}

function M.run()

  local function T(name, ok, detail)
    if ok then
      harness.pass = harness.pass + 1
    else
      harness.fail = harness.fail + 1
      print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
    end
  end

  local function sec(title)
    print("\n=== " .. title .. " ===")
  end


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

  -- ─────────────────────────────────────────────────────────────
  -- formatter
  -- ─────────────────────────────────────────────────────────────
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

  -- ─────────────────────────────────────────────────────────────
  -- RELATÓRIO
  -- ─────────────────────────────────────────────────────────────
end

return M
