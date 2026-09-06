-- providers/google_grounding.lua — Fachada do Google Search Grounding via Interactions API.
-- Refatorado a partir do monólito de 263 linhas (Issue #27).
-- Apenas importa submódulos e reexporta a API pública. Orquestração de search fica aqui.
--
-- MIGRADO em 2026-07-27: Google descontinuou generateContent para grounding.
-- Endpoint: POST /v1beta/interactions
-- Formato: { model, input, tools: [{type:"google_search"}] }
-- Resposta: { steps: [{type:"thought"}, {type:"google_search_call"}, {type:"google_search_result"}, {type:"model_output"}] }
--
-- Fallback chain: gemini-2.5-flash → gemini-2.5-flash-lite → gemini-2.5-flash-lite-preview-09-2025

local json = require("json")
local security = require("agent.security")
local constants = require("providers.google_grounding.constants")
local error_classifier = require("providers.google_grounding.error_classifier")
local response_extractor = require("providers.google_grounding.response_extractor")
local api_client = require("providers.google_grounding.api_client")
local formatter = require("providers.google_grounding.formatter")

local M = {}
M.id = "google_grounding"
M.name = "Google Search Grounding (Gemini)"

local function get_config()
  local config_mod = require("config")
  local cfg = config_mod.load()
  return (cfg.web_tools or {})
end

function M.search(query)
  local web = get_config()

  if not web.enabled then
    return "❌ Web Tools desativadas. Ative em Config › Web Tools."
  end

  local api_key = web.google_grounding_key
  if not api_key or api_key == "" then
    return "❌ Chave de Grounding não configurada. Vá em Config › Web Tools."
  end

  local safe, char = security.is_safe(api_key)
  if not safe then
    return "❌ Erro de segurança: chave de API contém caractere inválido '" .. char .. "'"
  end

  -- Fallback chain: tentar cada modelo até um funcionar
  local last_error = ""
  for _, model in ipairs(constants.MODELS) do
    local raw = api_client.call_api(model, api_key, query)

    if raw == "" then
      last_error = "❌ Sem resposta do Google. Verifique sua conexão."
    else
      local ok, data = pcall(json.decode, raw)
      if not ok then
        last_error = "❌ Resposta inválida do Google."
      elseif data.error then
        last_error = error_classifier.classify_error(data)
        -- Se erro de cota (429), tentar próximo modelo
        local code = data.error.code or 0
        local lower = (data.error.message or ""):lower()
        if code == 429 or lower:match("too_many_requests") then
          goto continue
        end
        -- Se erro de chave (403) ou payload (400), não adianta trocar modelo
        break
      else
        -- Sucesso!
        local response_text, sources, queries = response_extractor.extract_response(data)

        if response_text == "" then
          last_error = "🔍 Nenhum resultado para: " .. query
          break  -- output vazio, sem mais o que tentar
        else
          return formatter.format_result(query, response_text, sources, queries)
        end
      end
    end

    ::continue::
  end

  return last_error
end

return M
