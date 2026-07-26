-- providers/google_grounding.lua — Google Search Grounding via Gemini API
-- IMPORTANTE: Use modelo ESTÁVEL, não preview.
-- gemini-3-flash-preview → limit:0 para grounding (não funciona no free tier)
-- gemini-2.5-flash       → até 500 req/dia grátis no free tier

local json = require("json")
local security = require("agent.security")
local M = {}
M.id = "google_grounding"
M.name = "Google Search Grounding (Gemini)"

local GROUNDING_MODEL = "gemini-2.5-flash"

local function get_config()
  local config_mod = require("config")
  local cfg = config_mod.load()
  return (cfg.web_tools or {})
end

local function parse_retry(msg)
  local s = msg:match("retry in (%d+%.?%d*)s")
  return s and (" Tente em " .. s .. "s.") or ""
end

local function classify_error(err)
  local code  = err.code or 0
  local msg   = err.message or "Erro desconhecido"
  local lower = msg:lower()

  -- limit:0 = feature bloqueada neste tier/modelo (não é cota esgotada)
  if lower:match("limit:%s*0") or lower:match("free_tier") then
    return "❌ Search Grounding indisponível no free tier com este modelo.\n"
        .. "  Troque o modelo para 'gemini-2.5-flash' (estável) em google_grounding.lua.\n"
        .. "  Detalhe: " .. msg
  end

  -- 429 = rate limit por minuto ou cota diária
  if code == 429 then
    local retry = parse_retry(msg)
    if lower:match("quota") or lower:match("resource_exhausted") then
      return "❌ Cota de Search Grounding esgotada." .. retry .. "\n"
          .. "  Limite free tier: 500 req/dia. Detalhe: " .. msg
    end
    return "❌ Rate limit atingido." .. retry .. "\n"
        .. "  Detalhe: " .. msg
  end

  -- 403 = chave inválida
  if code == 403 or lower:match("api.key") or lower:match("permission") then
    return "❌ Chave de API inválida ou sem permissão para Grounding.\n"
        .. "  Verifique em Config › Web Tools. Detalhe: " .. msg
  end

  return "❌ Erro Google [" .. tostring(code) .. "]: " .. msg
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

  local url = "https://generativelanguage.googleapis.com/v1beta/models/"
    .. GROUNDING_MODEL .. ":generateContent"

  local pl = string.format(
    '{"contents":[{"parts":[{"text":%s}]}],"tools":[{"google_search":{}}]}',
    json.encode(query)
  )

  local TMPDIR = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
  local tmp_path = TMPDIR .. "/gg_search.json"
  local tmp = io.open(tmp_path, "w")
  if not tmp then return "❌ Não foi possível criar arquivo temporário." end
  tmp:write(pl); tmp:close()

  local cmd = string.format(
    'curl -s --max-time 20 --speed-time 10 --speed-limit 1 -X POST "%s"'
    .. ' -H "Content-Type: application/json"'
    .. ' -H "x-goog-api-key: %s"'
    .. ' -d @%s 2>/dev/null',
    url, api_key, tmp_path
  )

  local h   = io.popen(cmd)
  local raw = h and h:read("*a") or ""
  if h then h:close() end
  os.remove(tmp_path)

  if raw == "" then
    return "❌ Sem resposta do Google. Verifique sua conexão."
  end

  local ok, data = pcall(json.decode, raw)
  if not ok then return "❌ Resposta inválida do Google." end

  if data.error then return classify_error(data.error) end

  local candidates = data.candidates
  if not candidates or #candidates == 0 then
    return "🔍 Nenhum resultado para: " .. query
  end

  local candidate    = candidates[1]
  local parts        = candidate.content and candidate.content.parts
  local response_text = ""
  local sources      = {}

  if parts then
    for _, part in ipairs(parts) do
      if part.text then response_text = response_text .. part.text end
    end
  end

  local meta = candidate.groundingMetadata
  if meta and meta.groundingChunks then
    for _, chunk in ipairs(meta.groundingChunks) do
      if chunk.web and chunk.web.uri then
        sources[#sources + 1] = chunk.web.uri
      end
    end
  end

  if response_text == "" then
    return "🔍 O Google não retornou resposta para: " .. query
  end

  local out = { "🔍 **Resultado:** \"" .. query .. "\"\n", response_text }
  if #sources > 0 then
    out[#out + 1] = "\n📎 **Fontes:**"
    for i, uri in ipairs(sources) do
      out[#out + 1] = i .. ". " .. uri
    end
  end

  return table.concat(out, "\n")
end

return M
