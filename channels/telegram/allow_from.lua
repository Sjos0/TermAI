-- channels/telegram/allow_from.lua — Allowlist de chat_id autorizados.
-- Sem isso, qualquer pessoa que descubra o bot controlaria o agente.
local config = require("config")
local M = {}

function M.is_allowed(chat_id)
  local list = config.get("channels.telegram.allowed_chat_ids")
  if type(list) ~= "table" or #list == 0 then return false end
  local id_str = tostring(chat_id)
  for _, allowed in ipairs(list) do
    if tostring(allowed) == id_str then return true end
  end
  return false
end

return M
