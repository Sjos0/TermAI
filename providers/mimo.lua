-- providers/mimo.lua — Xiaomi MiMo via MiMo Platform (OpenAI-compatible)
-- API Base: https://api.mimo.xiaomi.com/v1
-- Obtenha seu Token/Key gratuito em: https://platform.xiaomimimo.com

return {
  id = "mimo",
  name = "Xiaomi MiMo",
  baseUrl = "https://api.mimo.xiaomi.com/v1",
  api = "openai-completions",
  needs_key = true,
  key_hint = "token da plataforma (ou sk-...)",
  docs = "https://platform.xiaomimimo.com",
  models = {
    {
      id = "mimo-v2.5-pro",
      name = "MiMo 2.5 Pro (Gratuito/Trial via Token)",
      reasoning = true,
      reasoning_style = "thinking_tags",
      input = {"text", "image"},
      cost = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 1000000,
      maxTokens = 32768,
    },
    {
      id = "mimo-v2.5-flash",
      name = "MiMo 2.5 Flash",
      reasoning = false,
      input = {"text"},
      cost = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 256000,
      maxTokens = 16384,
    },
    {
      id = "mimo-v2.5-omni",
      name = "MiMo 2.5 Omni",
      reasoning = false,
      input = {"text", "image", "audio"},
      cost = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 256000,
      maxTokens = 16384,
    }
  }
}
