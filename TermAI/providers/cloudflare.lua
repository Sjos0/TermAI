-- cloudflare.lua — Cloudflare Workers AI
-- OpenAI-compatible endpoint. Account ID faz parte da URL base.
-- O providers.lua pede o Account ID separado da API key.
return {
  id                 = "cloudflare",
  name               = "Cloudflare Workers AI",
  requires_account_id = true,   -- providers.lua usa este flag para pedir o Account ID
  account_id_hint    = "Ex: 670e36e6b9bbe24d257b326c8afb3265  (dash.cloudflare.com → lado direito)",
  -- baseUrl usa placeholder — substituído pelo Account ID real em providers.lua
  baseUrl   = "https://api.cloudflare.com/client/v4/accounts/%s/ai/v1",
  api       = "openai-completions",
  needs_key = true,
  key_hint  = "Token gerado em dash.cloudflare.com → Workers AI → Use REST API → Create token",
  docs      = "https://developers.cloudflare.com/workers-ai/get-started/rest-api/",
  models    = {
    {
      id              = "@cf/moonshotai/kimi-k2.6",
      name            = "Kimi K2.6 · Moonshot AI (262k ctx)",
      reasoning       = true,
      reasoning_style = "thinking_tags",  -- envia <think>...</think> no stream
      input           = {"text", "image"},
      cost            = {input = 0.95, output = 4.00, cacheRead = 0.16, cacheWrite = 0},
      contextWindow   = 262144,
      maxTokens       = 8192,
    },
  },
}
