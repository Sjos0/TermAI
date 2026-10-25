-- agent/api/summarizer/runner.lua — Orquestrador do fluxo assíncrono de chamada à API de resumo.
-- Cada tentativa captura o PID do curl; timeout/retry matam o processo antes de
-- remover os temporários (Issue #73).

local M = {}

local N = require("agent.api.summarizer.runner.nucleo_1")(M)
require("agent.api.summarizer.runner.parte_1")(M, N)
require("agent.api.summarizer.runner.parte_2")(M, N)

return M
