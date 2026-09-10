-- agent/loop/response_utils.lua — Utilitários de protocolo de resposta do loop ReAct.
local M = {}

--- Remove a tag [FLUSH_DONE] e trim de espaços nas bordas.
-- @param text string|nil
-- @return string
function M.strip_flush_tag(text)
  if not text then return "" end
  return (text:gsub("%[FLUSH_DONE%]", ""):match("^%s*(.-)%s*$") or "")
end

--- Detecta resposta que anuncia uma ação (termina em ":") mas não chama tool.
-- v2.2 do loop ReAct.
-- @param display_text string|nil
-- @return boolean
function M.is_unfulfilled_intent(display_text)
  if not display_text or display_text == "" then return false end
  local trimmed = display_text:match("^%s*(.-)%s*$") or display_text
  return trimmed:sub(-1) == ":"
end

return M
