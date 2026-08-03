-- agent/api/request_stream/error_log.lua — Diagnóstico de erros de API.
-- Três responsabilidades pequenas e relacionadas: (1) extrair mais detalhe
-- de um erro estruturado do provider do que só `.message`, (2) reconhecer
-- os formatos de corpo de erro usados pelos providers do projeto, e
-- (3) persistir o corpo bruto em disco pra pós-mortem (o terminal rola e
-- perde o erro).
local json = require("json")
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

-- Extrai uma mensagem de erro legível do corpo bruto (não-stream) de uma
-- resposta HTTP. Reconhece três formatos vistos nos providers do projeto:
--   OpenAI-style:  {"error": {message, type, code, param}}
--   Array style:   [{"error": {...}}]
--   Formato plano: {"message": ..., "type": ..., "code": ...}  (ex: NVIDIA NIM)
-- Retorna nil se o corpo estiver vazio ou não bater com nenhum formato
-- conhecido — quem chama decide o fallback (ex: "Sem resposta do servidor").
function M.extract_from_body(body)
  if not body or body == "" then return nil end
  local ok, ed = pcall(json.decode, body)
  if not ok or type(ed) ~= "table" then return nil end
  if ed.error then return M.describe(ed.error) end
  if ed[1] and ed[1].error then return M.describe(ed[1].error) end
  if ed.message then return M.describe(ed) end
  return nil
end

return M
