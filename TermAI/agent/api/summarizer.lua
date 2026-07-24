-- agent/api/summarizer.lua — Condensação/sumarização de histórico via API (Padrão Fachada).
local M = {}

-- Carrega submódulos especializados de domínio
local runner = require("agent.api.summarizer.runner")

-- Reexporta a API mapeando idêntico ao contrato original
M.summarizar = runner.summarizar

return M
