-- commands/update.lua — Atualiza o clone local pela última release publicada (padrão),
-- pela branch main (--main) ou volta ao commit anterior (--rollback).
-- Issue #41 (flags), #74 (releases). Regras puras em tools/update/release.lua.

local N = require("commands.update.nucleo")
local c = N.c
local flags = require("commands.update.flags").parse(arg)
if not flags then return end

local title = flags.rollback and "Voltando à versão anterior..." or
              flags.check and "Verificando atualizações..." or
              (flags.dry_run and "Dry-run (nenhuma alteração será aplicada)" or "Atualizando TermAI...")

io.write("\n")
io.write("  " .. c.bold .. title .. c.reset .. "\n\n")

require("commands.update.checagem").executar(flags)
if flags.rollback then require("commands.update.rollback").executar(flags) end
require("commands.update.aplicar").executar(flags)
