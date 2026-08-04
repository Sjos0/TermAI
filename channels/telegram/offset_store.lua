-- channels/telegram/offset_store.lua — Persistência atômica do offset de
-- long polling. O Termux pode matar o processo em background (ver
-- Contexto_Ambiental.md §3) — sem isso, updates seriam reprocessados ou
-- perdidos ao reiniciar.
local M = {}
local DIR  = (os.getenv("HOME") or "/data/data/com.termux/files/home") .. "/.TermAI"
local PATH = DIR .. "/telegram_offset"

function M.load()
  local f = io.open(PATH, "r")
  if not f then return 0 end
  local n = f:read("*n")
  f:close()
  return n or 0
end

function M.save(offset)
  os.execute('mkdir -p "' .. DIR .. '"')
  local tmp = PATH .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return false end
  f:write(tostring(offset))
  f:close()
  return os.rename(tmp, PATH) ~= nil
end

return M
