-- channels/telegram/approval.lua — Aprovação de tools/comandos via chat,
-- substitui o diálogo bloqueante de terminal quando não há TTY. Contratos
-- de retorno idênticos aos módulos originais (ver tools/exec/permissions_ui.lua
-- e agent/hooks/bash_patterns/ui.lua) para não exigir mudança nos callers.
local api          = require("channels.telegram.api")
local offset_store = require("channels.telegram.offset_store")
local M = {}

local cur = { token = nil, chat_id = nil }
local bash_denials = {}
local MAX_WAIT = 300 -- segundos esperando resposta antes de negar por segurança

-- Chamado pelo bridge ANTES de agent.loop.rodar.
function M.set_current(token, chat_id)
  cur.token, cur.chat_id = token, chat_id
end

-- Espera a próxima mensagem de texto do chat autorizado; ignora e descarta
-- (avançando o offset) mensagens de qualquer outro chat_id enquanto espera.
local function wait_for_reply()
  local waited = 0
  while waited < MAX_WAIT do
    local offset  = offset_store.load()
    local updates = api.get_updates(cur.token, offset, 25)
    if updates then
      for _, upd in ipairs(updates) do
        offset_store.save(upd.update_id + 1)
        local msg = upd.message
        if msg and msg.chat and tostring(msg.chat.id) == tostring(cur.chat_id) and msg.text then
          return msg.text:lower():match("^%s*(.-)%s*$")
        end
      end
    end
    waited = waited + 25
  end
  return nil
end

local function ask(question)
  api.send_message(cur.token, cur.chat_id, question)
  return wait_for_reply()
end

-- Contrato: M.ask_tool(...) -> choice, suggested_pattern
-- choice em {"once","always","deny","block","cancel"}.
function M.ask_tool(tool_name, command, failed_sub, warnings)
  local display  = tostring(command or ""):sub(1, 300)
  local question = string.format(
    "🔒 Permissão — %s\nComando: %s\n\nResponda: sim / sempre / não / bloquear",
    tool_name, display)

  local reply = ask(question)
  if not reply then
    api.send_message(cur.token, cur.chat_id, "⏱️ Tempo esgotado — negado por segurança.")
    return "cancel", ""
  end
  if reply == "sim" or reply == "s" or reply == "1" then return "once", "" end
  if reply == "sempre" or reply == "2" then return "always", "" end
  if reply == "bloquear" or reply == "4" then return "block", "" end
  return "deny", ""
end

-- Contrato: M.ask_bash(cmd, failed_sub) -> boolean
function M.ask_bash(cmd, failed_sub)
  local display  = tostring(cmd or ""):sub(1, 300)
  local question = string.format("🔒 Comando Bash: %s\n\nResponda: sim / sempre / não", display)

  local reply = ask(question)
  if not reply then
    api.send_message(cur.token, cur.chat_id, "⏱️ Tempo esgotado — negado por segurança.")
    return false
  end
  if reply == "sim" or reply == "s" or reply == "1" then
    bash_denials[cmd] = 0
    return true
  end
  if reply == "sempre" or reply == "2" then
    local ok_rules, rules = pcall(require, "agent.hooks.bash_patterns.rules")
    if ok_rules then rules.add_pattern(failed_sub or cmd) end
    bash_denials[cmd] = 0
    return true
  end

  bash_denials[cmd] = (bash_denials[cmd] or 0) + 1
  if bash_denials[cmd] >= 3 then
    local ok_perms, perms = pcall(require, "agent.hooks.permissions")
    if ok_perms then perms.set("exec", "blocked") end
    bash_denials[cmd] = 0
    api.send_message(cur.token, cur.chat_id, "🚫 Ferramenta 'exec' bloqueada após 3 recusas.")
  end
  return false
end

return M
