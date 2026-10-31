-- tests/google_grounding_units_spec/01_n_unit_tests_google_ground.lua — parte de google_grounding_units_spec.lua (ver fachada).
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


  print("\n=== Unit tests: google_grounding submodules (Issue #27 / PR #37) ===\n")

  -- ─────────────────────────────────────────────────────────────
  -- constants
  -- ─────────────────────────────────────────────────────────────
  sec("constants")

  local constants = require("providers.google_grounding.constants")

  T("MODELS é table com ≥1 modelo", type(constants.MODELS) == "table" and #constants.MODELS >= 1)
  T("Primeiro modelo é gemini-2.5-flash", constants.MODELS[1] == "gemini-2.5-flash")
  T("INTERACTIONS_URL aponta para /v1beta/interactions",
    type(constants.INTERACTIONS_URL) == "string"
    and constants.INTERACTIONS_URL:find("v1beta/interactions") ~= nil
    and constants.INTERACTIONS_URL:find("generateContent") == nil)

  -- ─────────────────────────────────────────────────────────────
  -- error_classifier
  -- ─────────────────────────────────────────────────────────────
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

  -- ─────────────────────────────────────────────────────────────
  -- larguras responsivas (#331): a saída do grounding nunca estoura tw
  -- ─────────────────────────────────────────────────────────────
  sec("larguras responsivas (#331)")

  do
    local core    = require("ui.core")
    local card    = require("ui.card")
    local largura = require("ui.largura")
    local fmt_gg  = require("providers.google_grounding.formatter")
    local BG, FG, DIM = "\27[48;5;234m", "\27[38;5;255m", "\27[38;5;245m"

    -- Saída real do grounding: texto longo, acentuação e URL comprida.
    local gg = fmt_gg.format_result(
      "pergunta longa sobre um assunto pesquisado na web com acentuação ção",
      "Resposta com link https://exemplo.invalid/muito/longo/caminho/da/fonte/relevante/2026",
      { { url = "https://exemplo.invalid/muito/longo/caminho/da/fonte/relevante/2026",
          title = "Fonte relevante" } },
      { "consulta um", "consulta dois" })

    local linhas_gg = {}
    for ln in (gg .. "\n"):gmatch("([^\n]*)\n") do linhas_gg[#linhas_gg + 1] = ln end

    for _, tw in ipairs({ 40, 50, 54, 80 }) do
      -- Caminho REAL do card: ele pinta exatamente tw colunas, nunca mais.
      local rows = card.body_rows(linhas_gg, tw)
      local pior = 0
      for _, r in ipairs(rows) do
        local line = card.bg_row(BG, FG, r.prefix, r.dim and DIM or FG, r.text, tw)
        local w = largura.colunas(line)
        if w > pior then pior = w end
      end
      T(string.format("[#331 gg tw=%d] nenhuma linha do card excede tw (pior=%d)", tw, pior),
        pior <= tw)
    end
  end

  -- ─────────────────────────────────────────────────────────────
  -- response_extractor
  -- ─────────────────────────────────────────────────────────────
end

return M
