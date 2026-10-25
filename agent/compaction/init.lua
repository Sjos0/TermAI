-- compaction/init.lua — Fachada da compactação com LLM (State Reset).
-- v7: detecta corte no meio de um turno gigante e gera 2 resumos
-- separados + merge (REQ-2 → splitturn.lua). Mantém tudo do v6: teto de
-- tokens = max_tokens do modelo (REQ-6), geração+confirmação em turnos
-- separados sem ferramentas (REQ-8 → confirm.lua), corte por tokens
-- (REQ-1 → cutpoint.lua), merge com resumo anterior + foco customizável
-- (REQ-3/11 → summary_merge.lua), file tracking cumulativo (REQ-5 →
-- filetracking.lua), poda mecânica sem LLM (REQ-10 → poda.lua) e guarda
-- anti-thrashing (REQ-9). Streaming ao vivo mantido.
local M = {}

local N = require("agent.compaction.nucleo_1")(M)
require("agent.compaction.parte_1")(M, N)
require("agent.compaction.parte_2")(M, N)
require("agent.compaction.parte_3")(M, N)

return M
