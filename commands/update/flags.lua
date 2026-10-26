-- commands/update/flags.lua — lê as flags do comando e mostra a ajuda (--help).
local N = require("commands.update.nucleo")
local c = N.c

local M = {}

function M.parse(arg)
  local flags = { check = false, force = false, dry_run = false, main = false, rollback = false }
  for i = 2, #arg do
    local a = arg[i]
    if a == "--check" then flags.check = true
    elseif a == "--force" then flags.force = true
    elseif a == "--dry-run" then flags.dry_run = true
    elseif a == "--main" then flags.main = true
    elseif a == "--rollback" then flags.rollback = true
    elseif a == "--help" or a == "-h" then
      io.write("\n")
      io.write(c.bold .. "  TermAI update" .. c.reset .. " — atualiza para a última release publicada\n\n")
      io.write("  Uso:\n")
      io.write("    TermAI update            Atualiza para a última release\n")
      io.write("    TermAI update --check    Só verifica se há atualização\n")
      io.write("    TermAI update --dry-run  Mostra o que seria feito sem alterar\n")
      io.write("    TermAI update --main     Segue a branch main (em vez da release)\n")
      io.write("    TermAI update --rollback Volta ao commit de antes do último update\n")
      io.write("    TermAI update --force    Ignora working tree suja\n\n")
      return nil
    end
  end
  return flags
end

return M
