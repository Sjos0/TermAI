-- providers/kilo.lua — Kilo AI Gateway (OpenAI-compatible, 500+ modelos)
-- API key em: https://app.kilo.ai (API Keys)
-- Modelos no formato provider/model-name
-- Lista completa: https://api.kilo.ai/api/gateway/models

return {
  id        = "kilo",
  name      = "Kilo Gateway",
  baseUrl   = "https://api.kilo.ai/api/gateway",
  api       = "openai-completions",
  needs_key = true,
  key_hint  = "kilo-...",
  docs      = "https://app.kilo.ai",
  models    = {
    {
      id            = "kilo-auto/free",
      name          = "Kilo Auto Free (gratuito)",
      reasoning     = false,
      input         = {"text"},
      cost          = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 128000,
      maxTokens     = 50000,
    },
  },
}