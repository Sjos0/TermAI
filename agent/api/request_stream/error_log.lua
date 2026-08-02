-- agent/api/request_stream/error_log.lua — Diagnóstico de erros de API.
-- Duas responsabilidades pequenas e relacionadas: (1) extrair mais detalhe
-- de um erro estruturado do provider do que só `.message`, e (2) persistir
-- o corpo bruto em disco pra pós-mortem (o terminal rola e perde o erro).
local M = {}

local MAX_LOG_BYTES  = 200 * 1024 -- teto de disco (ver Contexto_Ambiental.md §1)
local MAX_BODY_CHARS = 4000       -- corpo bruto truncado por entrada

-- Gateways (ex: OpenCode Zen) costumam envolver o erro real do provider
-- downstream num campo genérico .message ("[400] Provider returned error").
-- Quando o provider expõe type/code/param, isso é o sinal de verdade.
function M.describe(err)
  if type(err) ~= "table" then return tostring(err) end
  local parts = { err.message or "erro sem mensagem" }
  if err.type  then parts[#parts + 1] = "tipo="  .. tostring(err.type)  end
  if err.code  then parts[#parts + 1] = "code="  .. tostring(err.code)  end
  if err.param then parts[#parts + 1] = "param=" .. tostring(err.param) end
  return table.concat(parts, " | ")
end

local function log_path()
  local d = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
  return d .. "/termai_api_errors.log"
end

-- Descarta o log se passar do teto -- evita crescimento sem controle no disco.
local function rotate_if_needed(path)
  local f = io.open(path, "r")
  if not f then return end
  local size = f:seek("end")
  f:close()
  if size and size > MAX_LOG_BYTES then os.remove(path) end
end

-- Registra uma falha de requisição com o máximo de contexto disponível:
-- tentativa, endpoint, mensagem já extraída e o corpo bruto da resposta.
function M.record(attempt, max_attempts, endpoint, reason, raw_body)
  local path = log_path()
  rotate_if_needed(path)
  local f = io.open(path, "a")
  if not f then return end
  local snippet = (raw_body or ""):sub(1, MAX_BODY_CHARS)
  f:write(string.format(
    "[%s] tentativa %d/%d endpoint=%s\n  motivo: %s\n  corpo_bruto: %s\n\n",
    os.date("%Y-%m-%d %H:%M:%S"), attempt, max_attempts,
    tostring(endpoint), tostring(reason), snippet))
  f:close()
end

return M
