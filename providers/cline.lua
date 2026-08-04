-- providers/cline.lua — Cline (ClinePass, gateway de assinatura da Cline)
-- Endpoint OpenAI-compatible: https://api.cline.bot/api/v1
-- API key em: https://app.cline.bot (conta Cline -> ClinePass)
local json = require("json")

local M = {
  id        = "cline",
  name      = "Cline (ClinePass)",
  baseUrl   = "https://api.cline.bot/api/v1",
  api       = "openai-completions",
  needs_key = true,
  key_hint  = "chave da sua conta Cline (gerada em app.cline.bot)",
  docs      = "https://docs.cline.bot/getting-started/clinepass",
  models    = {
    -- Curados a partir dos defaults conhecidos do ClinePass. A lista real e
    -- atualizada vem de fetch_remote_models() (endpoint "recommended" abaixo);
    -- estes servem de fallback e para preencher valores default no
    -- fluxo manual quando o fetch falhar.
    {
      id            = "zai/glm-5.2",
      name          = "GLM 5.2",
      reasoning     = true,
      reasoning_style = "openrouter",
      input         = {"text"},
      cost          = {input=0.000000062, output=0.000000424, cacheRead=0, cacheWrite=0},
      contextWindow = 128000,
      maxTokens     = 8192,
    },
    {
      id            = "moonshotai/kimi-k3",
      name          = "Kimi K3",
      reasoning     = true,
      reasoning_style = "openrouter",
      input         = {"text"},
      cost          = {input=0, output=0, cacheRead=0, cacheWrite=0},
      contextWindow = 128000,
      maxTokens     = 8192,
    },
  },
}

-- Busca a lista de modelos disponíveis na API da Cline via endpoint público.
-- Retorna array de modelos (recommended + free + clinePass) ou nil, erro.
function M.fetch_remote_models()
  local cmd = 'curl -s -w "\\n%{http_code}" --max-time 10 '
    .. '"https://api.cline.bot/api/v1/ai/cline/recommended-models" 2>/dev/null'
  local h = io.popen(cmd)
  if not h then return nil, "Não foi possível executar curl" end
  local r = h:read("*a")
  h:close()
  local body, http_code = r:match("^(.-)\n(%d+)$")
  if not body then return nil, "Sem resposta da API" end
  http_code = tonumber(http_code)
  if http_code ~= 200 then return nil, "HTTP " .. tostring(http_code) end
  local ok, data = pcall(json.decode, body)
  if not ok or type(data) ~= "table" then
    return nil, "JSON inválido na resposta"
  end
  -- Merge recommended + free + clinePass em uma lista só
  local all = {}
  for _, m in ipairs(data.recommended or {}) do
    m.source = "recommended"
    all[#all + 1] = m
  end
  for _, m in ipairs(data.free or {}) do
    m.source = "free"
    all[#all + 1] = m
  end
  for _, m in ipairs(data.clinePass or {}) do
    m.source = "clinePass"
    all[#all + 1] = m
  end
  if #all == 0 then return nil, "Nenhum modelo encontrado" end
  return all
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
