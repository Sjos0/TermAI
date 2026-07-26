-- providers/tavily_search.lua — Provedor de busca Tavily Search API.
-- v1: Retorna resultados estruturados e limpos para agentes de IA.
-- Baseado no contrato da API do OpenClaw (api.tavily.com/search).
local json = require("json")
local security = require("agent.security")
local M = {}
M.id = "tavily_search"
M.name = "Tavily Search (API)"
M.requires_key = true

local function get_config()
  local config_mod = require("config")
  local cfg = config_mod.load()
  return (cfg.web_tools or {})
end

function M.search(query)
  local web = get_config()

  if not web.enabled then
    return "❌ Web Tools desativadas. Ative em Config › Pesquisa Web."
  end

  local api_key = web.tavily_key
  if not api_key or api_key == "" then
    return "❌ Chave do Tavily não configurada. Vá em Config › Pesquisa Web."
  end

  local safe, char = security.is_safe(api_key)
  if not safe then
    return "❌ Erro de segurança: chave de API contém caractere inválido '" .. char .. "'"
  end

  local url = "https://api.tavily.com/search"
  local pl = json.encode({
    query = query,
    max_results = 5,
    search_depth = "basic",
    include_answer = false
  })

  local TMPDIR = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
  local tmp_path = TMPDIR .. "/tavily_search.json"
  local tmp = io.open(tmp_path, "w")
  if not tmp then return "❌ Não foi possível criar arquivo temporário." end
  tmp:write(pl); tmp:close()

  local cmd = string.format(
    'curl -s --max-time 20 --speed-time 10 --speed-limit 1 -X POST "%s"'
    .. ' -H "Content-Type: application/json"'
    .. ' -H "Authorization: Bearer %s"'
    .. ' -d @%s 2>/dev/null',
    url, api_key, tmp_path
  )

  local h = io.popen(cmd)
  local raw = h and h:read("*a") or ""
  if h then h:close() end
  os.remove(tmp_path)

  if raw == "" then
    return "❌ Sem resposta do Tavily. Verifique sua conexão."
  end

  local ok, data = pcall(json.decode, raw)
  if not ok then return "❌ Resposta inválida do Tavily." end

  if data.error or (data.detail and data.detail.error) then
    local err_msg = data.error or (data.detail and data.detail.error) or "Erro desconhecido na API"
    return "❌ Erro Tavily: " .. tostring(err_msg)
  end

  local results = data.results
  if not results or #results == 0 then
    return "🔍 Nenhum resultado para: " .. query
  end

  -- Formata no padrão unificado (compatível com Google Grounding e DDG)
  local out = { "🔍 **Resultado (Tavily Search):** \"" .. query .. "\"\n" }
  for i, r in ipairs(results) do
    out[#out + 1] = string.format("%d. **%s**", i, r.title or "Sem título")
    out[#out + 1] = "   " .. (r.content or "")
    out[#out + 1] = "   Font: " .. (r.url or "") .. "\n"
  end

  return table.concat(out, "\n")
end

return M
