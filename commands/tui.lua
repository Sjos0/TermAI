-- TermAI TUI — Interface interativa
-- Redireciona para o agente principal

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BASE = HOME .. "/TermAI"

dofile(BASE .. "/agente.lua")
