-- agente.lua — Ponto de entrada do TermAI.
-- Arquivo fachada: inicializa e delega para os módulos em agent/.

-- Instala a restauração do terminal na saída do processo (stty sane) ANTES
-- de qualquer outro módulo, para que os overrides de os.exit se encadeiem.
pcall(require, "ui.terminal_safe").install()

local context   = require("agent.context")
local startup   = require("agent.startup")
local main_loop = require("agent.main_loop")

-- Limpa resíduos de execuções anteriores (spinner órfão, flags e payloads em $TMPDIR).
local ok_spin, spin = pcall(require, "ui.spinner")
if ok_spin and spin.cleanup_startup then spin.cleanup_startup() end

local ctx, reset_info = context.build()
startup.run(ctx, reset_info)
main_loop.run(ctx)
