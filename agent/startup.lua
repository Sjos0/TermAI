-- startup.lua — Fachada + Loop de replay do histórico ao iniciar a TUI.
-- v2: Restaura tool_calls/tool_call_id; replay de native tool calls.
-- v2.4: usa ui.tool_replay (estado final direto, sem fase amarela/cursor-up) —
--       evita corrupção visual quando um turno tem múltiplas tool_calls.
-- v2.5: agrupa Read consecutivos no replay também (via tc_mapper.lua).
-- v5: reconstrói e expande pasted_texts na memória do agente.
-- v5.1: escapa o caractere especial % no gsub para prevenir crash de inicialização.
local M = {}

local N = require("agent.startup.nucleo")(M)
require("agent.startup.parte_1")(M, N)

return M
