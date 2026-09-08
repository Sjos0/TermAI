-- providers/google_grounding/constants.lua — Constantes do Google Search Grounding.
local M = {}

-- Modelo primário + fallbacks (todos suportam grounding no free tier)
M.MODELS = {
  "gemini-2.5-flash",
  "gemini-2.5-flash-lite",
  "gemini-2.5-flash-lite-preview-09-2025",
}

M.INTERACTIONS_URL = "https://generativelanguage.googleapis.com/v1beta/interactions"

return M
