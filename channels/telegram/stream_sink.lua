-- channels/telegram/stream_sink.lua — Sink de streaming para ui/stream.lua.
-- Edita a mensagem-placeholder periodicamente para simular o efeito de
-- streaming do terminal. É só o efeito cosmético incremental (best-effort);
-- a entrega final e autoritativa é feita por channels/telegram/api.lua
-- M.finalize, chamado por bridge.lua com o retorno real de agent.loop.rodar.
local api = require("channels.telegram.api")
local M = {}

local EDIT_INTERVAL = 1.2  -- segundos entre edições (evita flood limit do Telegram)
local MSG_LIMIT      = 4096

local s = { full = "", reasoning = "", last_edit = 0, token = nil, chat_id = nil, msg_id = nil }

-- Chamado pelo bridge ANTES de agent.loop.rodar — define onde editar.
function M.begin(token, chat_id, msg_id)
  s = { full = "", reasoning = "", last_edit = 0, token = token, chat_id = chat_id, msg_id = msg_id }
end

function M.start() end   -- stream_start: begin() já preparou o estado
function M.confirm() end -- stream_confirm: sem spinner no Telegram

function M.reasoning(tok)
  s.reasoning = s.reasoning .. tok -- não exibido ao usuário, só guardado p/ o JSONL
end

function M.token(tok)
  s.full = s.full .. tok
  local now = os.time()
  if s.msg_id and s.full ~= "" and (now - s.last_edit) >= EDIT_INTERVAL then
    s.last_edit = now
    api.edit_message(s.token, s.chat_id, s.msg_id, s.full:sub(1, MSG_LIMIT))
  end
end

function M.finish()
  return s.full, s.reasoning
end

return M
