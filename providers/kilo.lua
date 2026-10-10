-- Kilo AI Gateway: OpenAI-compatible endpoint, compatible with anonymous free routes.
-- Endpoint: https://api.kilo.ai/api/gateway/chat/completions
-- Catalog: https://api.kilo.ai/api/gateway/models
return {
  id = "kilo",
  name = "Kilo Gateway (Free)",
  baseUrl = "https://api.kilo.ai/api/gateway",
  api = "openai-completions",
  needs_key = false,
  docs = "https://kilo.ai/docs/gateway/models-and-providers",
  models = {
    {
      id = "kilo-auto/free",
      name = "Kilo Auto Free",
      reasoning = false,
      input = {"text"},
      cost = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 128000,
      maxTokens = 8192,
    },
    {
      id = "openrouter/free",
      name = "OpenRouter Free (via Kilo Gateway)",
      reasoning = false,
      input = {"text"},
      cost = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 128000,
      maxTokens = 8192,
    },
  },
}
