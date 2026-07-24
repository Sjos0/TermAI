-- providers/google.lua — Google Gemini via endpoint OpenAI-compatible oficial
-- API key em: https://aistudio.google.com/apikey
-- Modelos atualizados: maio 2026
-- ATENÇÃO: 2.0 Flash será desligado em 01/06/2026. Não usar para novos projetos.

return {
  id        = "google",
  name      = "Google Gemini",
  baseUrl   = "https://generativelanguage.googleapis.com/v1beta/openai",
  api       = "openai-completions",
  needs_key = true,
  key_hint  = "AIza...",
  docs      = "https://aistudio.google.com/apikey",
  models    = {
    -- ── Modelos gratuitos / tier gratuito ───────────────────────────────
    {
      id            = "gemini-3-flash-preview",
      name          = "Gemini 3 Flash (Gratuito)",
      reasoning     = true,
      reasoning_style = "thinking_tags",
      input         = {"text", "image"},
      cost          = {input=0.50, output=3.00, cacheRead=0.05, cacheWrite=0},
      contextWindow = 1000000,
      maxTokens     = 32768,
    },
    -- ── Gemma 4 (Open weights — gratuito) ───────────────────────────────
    {
      id            = "gemma-4-31b-it",
      name          = "Gemma 4 31B (Open)",
      reasoning     = true,
      reasoning_style = "thinking_tags",
      input         = {"text", "image"},
      cost          = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 131072,
      maxTokens     = 8192,
    },
    {
      id            = "gemma-4-26b-a4b-it",
      name          = "Gemma 4 26B MoE (Open)",
      reasoning     = true,
      reasoning_style = "thinking_tags",
      input         = {"text", "image"},
      cost          = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 131072,
      maxTokens     = 8192,
    },
    -- ── Família Gemini 3.x (pagos) ──────────────────────────────────────
    {
      id            = "gemini-3.1-pro-preview",
      name          = "Gemini 3.1 Pro",
      reasoning     = true,
      reasoning_style = "thinking_tags",
      input         = {"text", "image"},
      cost          = {input=2.00, output=12.00, cacheRead=0.20, cacheWrite=0},
      contextWindow = 2000000,
      maxTokens     = 65536,
    },
    {
      id            = "gemini-3.1-flash-lite-preview",
      name          = "Gemini 3.1 Flash-Lite",
      reasoning     = false,
      reasoning_style = "thinking_tags",
      input         = {"text", "image"},
      cost          = {input=0.25, output=1.50, cacheRead=0.025, cacheWrite=0},
      contextWindow = 1000000,
      maxTokens     = 32768,
    },
    -- ── Família Gemini 2.5 (legacy, ainda funcional) ─────────────────────
    {
      id            = "gemini-2.5-pro",
      name          = "Gemini 2.5 Pro (Legacy)",
      reasoning     = true,
      reasoning_style = "thinking_tags",
      input         = {"text", "image"},
      cost          = {input=1.25, output=10.00, cacheRead=0.31, cacheWrite=0},
      contextWindow = 1000000,
      maxTokens     = 65536,
    },
    {
      id            = "gemini-2.5-flash",
      name          = "Gemini 2.5 Flash (Legacy)",
      reasoning     = true,
      reasoning_style = "thinking_tags",
      input         = {"text", "image"},
      cost          = {input=0.15, output=0.60, cacheRead=0.037, cacheWrite=0},
      contextWindow = 1000000,
      maxTokens     = 32768,
    },
    {
      id            = "gemini-2.5-flash-lite",
      name          = "Gemini 2.5 Flash-Lite (Legacy)",
      reasoning     = false,
      reasoning_style = "thinking_tags",
      input         = {"text", "image"},
      cost          = {input=0.10, output=0.40, cacheRead=0.025, cacheWrite=0},
      contextWindow = 1000000,
      maxTokens     = 32768,
    },
  },
}
