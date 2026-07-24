-- agente.lua — Ponto de entrada do TermAI.
-- Arquivo fachada: inicializa e delega para os módulos em agent/.

local context   = require("agent.context")
local startup   = require("agent.startup")
local main_loop = require("agent.main_loop")

local ctx, reset_info = context.build()
startup.run(ctx, reset_info)
main_loop.run(ctx)
