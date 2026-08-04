-- agente_telegram.lua — Ponto de entrada do canal Telegram do TermAI.
-- Espelha agente.lua, trocando main_loop (TTY) por channels.telegram (chat).
local context  = require("agent.context")
local startup  = require("agent.startup")
local telegram = require("channels.telegram")

local ctx = context.build()
startup.run(ctx, nil)
telegram.run(ctx)
