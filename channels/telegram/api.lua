-- channels/telegram/api.lua — Fachada de baixo nível para a Bot API do
-- Telegram. curl + payload em arquivo, mesmo padrão de agent/api (ver
-- Estilo_de_codigo.md §4). Sem parse_mode: texto puro, evita erros de
-- escape do MarkdownV2.
local json  = require("json")
local utils = require("agent.api.utils")

local M = {}
local BASE      = "https://api.telegram.org/bot"
local MSG_LIMIT = 4096

local function call(token, method, params, max_time)
  local pl  = json.encode(params or {})
  local tmp = utils.make_tmp_path()
  local f = io.open(tmp, "w")
  if not f then return nil, "não foi possível criar arquivo temporário" end
  f:write(pl); f:close()

  local cmd = string.format(
    'curl -s --max-time %d -X POST "%s%s/%s" -H "Content-Type: application/json" -d @%s 2>/dev/null',
    max_time or 20, BASE, token, method, tmp)

  local h = io.popen(cmd)
  local body = h and h:read("*a") or ""
  if h then h:close() end
  os.remove(tmp)

  local ok, decoded = pcall(json.decode, body)
  if not ok or not decoded then return nil, "resposta inválida da API do Telegram" end
  if decoded.ok == false then return nil, decoded.description or "erro desconhecido" end
  return decoded.result, nil
end

-- Envia texto. Retorna o message_id enviado, ou nil + erro.
function M.send_message(token, chat_id, text)
  local res, err = call(token, "sendMessage", { chat_id = chat_id, text = text })
  return res and res.message_id or nil, err
end

-- Edita uma mensagem já enviada (efeito de streaming).
function M.edit_message(token, chat_id, message_id, text)
  local _, err = call(token, "editMessageText",
    { chat_id = chat_id, message_id = message_id, text = text })
  return err == nil, err
end

-- Long polling. timeout em segundos (Telegram aceita até ~50).
function M.get_updates(token, offset, timeout)
  return call(token, "getUpdates",
    { offset = offset, timeout = timeout, allowed_updates = { "message" } },
    timeout + 15)
end

-- Entrega o texto final na mensagem-placeholder (edita) e envia o restante
-- como mensagens extras se ultrapassar o limite de 4096 chars do Telegram.
function M.finalize(token, chat_id, message_id, text)
  text = (text ~= "" and text) or "(sem resposta)"
  M.edit_message(token, chat_id, message_id, text:sub(1, MSG_LIMIT))
  for i = MSG_LIMIT + 1, #text, MSG_LIMIT do
    M.send_message(token, chat_id, text:sub(i, i + MSG_LIMIT - 1))
  end
end

return M
