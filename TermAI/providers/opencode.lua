-- providers/opencode.lua — OpenCode Zen (gateway curado de modelos)
-- Endpoint OpenAI-compatible: https://opencode.ai/zen/v1
-- API key em: https://opencode.ai/auth
local json = require("json")

local M = {
  id        = "opencode",
  name      = "OpenCode Zen",
  baseUrl   = "https://opencode.ai/zen/v1",
  api       = "openai-completions",
  needs_key = true,
  key_hint  = "sk-z...",
  docs      = "https://opencode.ai/auth",
  models    = {
    {
      id            = "opencode/claude-opus-4-6",
      name          = "Claude Opus 4.6 (Zen)",
      reasoning     = true,
      input         = {"text"},
      cost          = {input=0.015, output=0.075, cacheRead=0, cacheWrite=0},
      contextWindow = 977000,
      maxTokens     = 32768,
    },
    {
      id            = "opencode/claude-sonnet-4-6",
      name          = "Claude Sonnet 4.6 (Zen)",
      reasoning     = true,
      input         = {"text"},
      cost          = {input=0.003, output=0.015, cacheRead=0, cacheWrite=0},
      contextWindow = 200000,
      maxTokens     = 16384,
    },
    {
      id            = "opencode/claude-haiku-4-5",
      name          = "Claude Haiku 4.5 (Zen)",
      reasoning     = false,
      input         = {"text"},
      cost          = {input=0.0008, output=0.004, cacheRead=0, cacheWrite=0},
      contextWindow = 200000,
      maxTokens     = 16384,
    },
    {
      id            = "opencode/gpt-5",
      name          = "GPT-5 (Zen)",
      reasoning     = true,
      input         = {"text"},
      cost          = {input=0.01, output=0.04, cacheRead=0, cacheWrite=0},
      contextWindow = 1000000,
      maxTokens     = 32768,
    },
    {
      id            = "opencode/gpt-5-nano",
      name          = "GPT-5 Nano (Zen)",
      reasoning     = false,
      input         = {"text"},
      cost          = {input=0.0005, output=0.002, cacheRead=0, cacheWrite=0},
      contextWindow = 128000,
      maxTokens     = 16384,
    },
    {
      id            = "opencode/gemini-3.1-pro",
      name          = "Gemini 3.1 Pro (Zen)",
      reasoning     = true,
      input         = {"text"},
      cost          = {input=0.0025, output=0.01, cacheRead=0, cacheWrite=0},
      contextWindow = 1000000,
      maxTokens     = 8192,
    },
    {
      id            = "opencode/glm-5.1",
      name          = "GLM 5.1 (Zen)",
      reasoning     = true,
      input         = {"text"},
      cost          = {input=0.001, output=0.004, cacheRead=0, cacheWrite=0},
      contextWindow = 131072,
      maxTokens     = 8192,
    },
    {
      id            = "opencode/big-pickle",
      name          = "Big Pickle (Zen)",
      reasoning     = false,
      input         = {"text"},
      cost          = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 128000,
      maxTokens     = 8192,
    },
    {
      id            = "opencode/minimax-m2.5-free",
      name          = "MiniMax M2.5 (Zen Free)",
      reasoning     = false,
      input         = {"text"},
      cost          = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 197000,
      maxTokens     = 8192,
    },
  },
}

-- Busca a lista crua de modelos no endpoint público da Zen.
-- Retorna array de {id, created, owned_by} (ID sem prefixo "opencode/") ou nil, erro.
function M.fetch_remote_models()
  local cmd = 'curl -s -w "\\n%{http_code}" --max-time 10 '
    .. '"https://opencode.ai/zen/v1/models" 2>/dev/null'
  local h = io.popen(cmd)
  if not h then return nil, "Não foi possível executar curl" end
  local r = h:read("*a")
  h:close()
  local body, http_code = r:match("^(.-)\n(%d+)$")
  if not body then return nil, "Sem resposta da API" end
  http_code = tonumber(http_code)
  if http_code ~= 200 then return nil, "HTTP " .. tostring(http_code) end
  local ok, data = pcall(json.decode, body)
  if not ok or not data or not data.data then
    return nil, "JSON inválido na resposta"
  end
  return data.data
end

-- Procura um modelo curado (hardcoded acima) a partir do ID puro vindo da API.
function M.find_curated(bare_id)
  local full_id = M.id .. "/" .. bare_id
  for _, m in ipairs(M.models) do
    if m.id == full_id then return m end
  end
  return nil
end

return M
