local store = require("models.store")
local M = {}

local ENDPOINT_MAP = {
  ["openai-completions"]       = function(p, id) return p.baseUrl .. "/chat/completions", "bearer" end,
  ["google-generative-ai"]     = function(p, id) return p.baseUrl .. "/models/" .. id .. ":generateContent?key=" .. (p.apiKey or ""), "none" end,
  ["ollama"]                   = function(p, _)   return p.baseUrl .. "/api/chat", "none" end,
  ["openai-codex-responses"]   = function(p, _)   return p.baseUrl .. "/responses", "bearer" end,
}

-- Busca dados suplementares do catálogo built-in
local function find_builtin_model(provider_id, model_id)
  local ok, providers_mod = pcall(require, "providers")
  if not ok then return nil end
  local prov = providers_mod.get(provider_id)
  if not prov then return nil end
  for _, m in ipairs(prov.models or {}) do
    if m.id == model_id then return m end
  end
  return nil
end

-- Busca o módulo built-in do PROVEDOR (não do modelo) — usado pro fallback
-- de reasoning_style quando o modelo específico não está no catálogo curado
-- (ex: modelo "free/contributor" pego ao vivo via fetch_remote_models).
local function find_builtin_provider(provider_id)
  local ok, providers_mod = pcall(require, "providers")
  if not ok then return nil end
  return providers_mod.get(provider_id)
end

function M.resolve(ref)
  local d = store.data()
  ref = ref or d.active
  if not ref or ref == "" then return nil, "Nenhum modelo ativo" end

  local provider_id, model_id = ref:match("^([^/]+)/(.+)$")
  if not provider_id or not model_id then
    return nil, "Referência inválida: " .. tostring(ref)
  end

  local provider = d.providers[provider_id]
  if not provider then
    return nil, "Provedor não encontrado: " .. provider_id
  end

  local model = nil
  for _, m in ipairs(provider.models or {}) do
    if m.id == model_id then model = m; break end
  end
  if not model then
    return nil, "Modelo não encontrado: " .. model_id
  end

  -- Merge com dados built-in (preenche campos faltantes)
  local builtin = find_builtin_model(provider_id, model_id)
  if builtin then
    for k, v in pairs(builtin) do
      if model[k] == nil then
        model[k] = v
      end
    end
  end

  local api_type = model.api or provider.api or "openai-completions"
  local builder = ENDPOINT_MAP[api_type] or ENDPOINT_MAP["openai-completions"]
  local endpoint, auth_style = builder(provider, model_id)

  -- Prioridade do reasoning_style: 1) o que está salvo no modelo (inclusive
  -- herdado do catálogo curado pelo merge acima), 2) o padrão do PROVEDOR
  -- (ex: qualquer modelo da OpenCode Zen herda "reasoning_effort" mesmo sem
  -- estar no catálogo curado), 3) "openrouter" como último fallback histórico.
  local builtin_provider = find_builtin_provider(provider_id)
  local default_style    = (builtin_provider and builtin_provider.default_reasoning_style) or "openrouter"

  return {
    ref              = ref,
    provider         = provider_id,
    model_id         = model_id,
    name             = model.name or model_id,
    endpoint         = endpoint,
    api_key          = provider.apiKey or "",
    api_type         = api_type,
    auth_style       = auth_style,
    max_tokens       = model.maxTokens or 4096,
    context_window   = model.contextWindow or 200000,
    reasoning        = model.reasoning or false,
    reasoning_style  = model.reasoning_style or default_style,
    input            = model.input or {"text"},
    cost             = model.cost or {input=0, output=0, cacheRead=0, cacheWrite=0},
  }
end

return M
