-- channels/telegram/bridge.lua — Ponte entre updates do Telegram e o loop do
-- agente. Espelha agent/main_loop.lua (Blocos 1,3,6) trocando I/O de
-- terminal por Telegram. Bloco 2 (leitura de input) e Bloco 4 (comandos de
-- terminal, /config etc.) não se aplicam a este canal na v1.
local ag_loop      = require("agent.loop")
local session      = require("session")
local timestamp    = require("agent.main_loop.timestamp")
local persistence  = require("agent.main_loop.persistence")
local compaction_h = require("agent.main_loop.compaction_handler")
local flush_h      = require("agent.main_loop.flush_handler")
local overflow_h   = require("agent.main_loop.overflow_handler")
local api          = require("channels.telegram.api")
local allow_from   = require("channels.telegram.allow_from")
local approval     = require("channels.telegram.approval")
local stream_sink  = require("channels.telegram.stream_sink")

local M = {}
local flush_msgs_start = nil

local function init_flush_index(ctx)
  if flush_msgs_start then return end
  local saved_idx = session.get_flush_index and session.get_flush_index() or nil
  if saved_idx then
    flush_msgs_start = saved_idx + 1
  elseif #ctx.msgs > 0 then
    flush_msgs_start = math.max(1, #ctx.msgs - 15)
  else
    flush_msgs_start = #ctx.msgs + 1
  end
end

function M.handle_update(ctx, token, update)
  local msg = update.message
  if not msg or not msg.text or not msg.chat then return end

  local chat_id = msg.chat.id
  if not allow_from.is_allowed(chat_id) then return end

  init_flush_index(ctx)

  local comp = compaction_h.handle(ctx, flush_msgs_start)
  flush_msgs_start = comp.flush_msgs_start

  local fl = flush_h.handle(ctx, msg.text, flush_msgs_start)
  flush_msgs_start = fl.flush_msgs_start

  local ts            = timestamp.capture()
  local stamped_input = "[" .. ts .. "] " .. msg.text
  local msgs_before   = #ctx.msgs

  approval.set_current(token, chat_id)
  local placeholder_id = api.send_message(token, chat_id, "…")
  stream_sink.begin(token, chat_id, placeholder_id)

  local resp, _, _, is_overflow, stream_complete, reasoning =
    ag_loop.rodar(ctx, stamped_input, "user")

  if is_overflow then
    local ov = overflow_h.handle(ctx, stamped_input, msgs_before, flush_msgs_start)
    msgs_before      = ov.msgs_before
    flush_msgs_start = ov.flush_msgs_start
    resp             = ov.resp
    stream_complete  = ov.stream_complete
    reasoning        = ov.reasoning
  end

  local save_input = "[" .. ts .. "] " .. msg.text
  persistence.save_exchange(ctx, msgs_before, reasoning, save_input, ctx.tokens_fresh, {}, stream_complete)

  api.finalize(token, chat_id, placeholder_id, resp or "")

  if stream_complete == false then
    api.send_message(token, chat_id, "⚠️ Resposta incompleta (timeout de stream).")
  end
end

return M
