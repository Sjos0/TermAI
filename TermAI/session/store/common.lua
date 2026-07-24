-- session/store/common.lua — Constantes e auxiliares de caminho compartilhados.
local M = {}

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
M.SESSIONS_DIR = HOME .. "/.TermAI/agents/main/sessions"

function M.jsonl_path(session_id)
  return M.SESSIONS_DIR .. "/" .. (session_id:gsub(":", "-")) .. ".jsonl"
end

return M
