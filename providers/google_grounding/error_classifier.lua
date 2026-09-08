-- providers/google_grounding/error_classifier.lua — Classificação de erros da API Google.
local M = {}

local function parse_retry(msg)
  local s = msg:match("retry in (%d+%.?%d*)s")
  return s and (" Tente em " .. s .. "s.") or ""
end

--- Classifica erro da resposta Google e retorna mensagem amigável.
-- @param data table Resposta decodificada contendo data.error
-- @return string Mensagem de erro formatada
function M.classify_error(data)
  local err = data.error
  if not err then return "❌ Erro desconhecido do Google." end

  local code  = err.code or 0
  local msg   = err.message or "Erro desconhecido"
  local lower = msg:lower()

  -- 429 / too_many_requests = cota esgotada
  if code == 429 or lower:match("too_many_requests") then
    local retry = parse_retry(msg)
    if lower:match("quota") or lower:match("resource_exhausted") then
      return "❌ Cota de Search Grounding esgotada." .. retry .. "\n"
          .. "  Limite free tier: 500 req/dia por modelo. Detalhe: " .. msg
    end
    return "❌ Rate limit atingido." .. retry .. "\n"
        .. "  Detalhe: " .. msg
  end

  -- 403 = chave inválida ou leaked
  if code == 403 then
    if lower:match("leaked") then
      return "❌ Chave de API comprometida (reported as leaked).\n"
          .. "  Gere uma nova chave em https://aistudio.google.com/apikey\n"
          .. "  e atualize em Config › Web Tools."
    end
    return "❌ Chave de API inválida ou sem permissão para Grounding.\n"
        .. "  Verifique em Config › Web Tools. Detalhe: " .. msg
  end

  -- 400 = payload inválido
  if code == 400 then
    return "❌ Requisição inválida. Verifique a configuração do provider.\n"
        .. "  Detalhe: " .. msg
  end

  return "❌ Erro Google [" .. tostring(code) .. "]: " .. msg
end

return M
