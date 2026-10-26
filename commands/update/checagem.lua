-- commands/update/checagem.lua — passos 1 a 4: git disponível, clone, remote origin e árvore limpa.
local N = require("commands.update.nucleo")
local c, git, run, step_ok, step_fail, step_warn = N.c, N.git, N.run, N.step_ok, N.step_fail, N.step_warn

local M = {}

function M.executar(flags)
  -- 1. git disponível
  local _, git_exit = run("command -v git")
  if git_exit ~= 0 then
    step_fail("git não encontrado no PATH")
    io.write("\n  Instale com:\n    pkg install git\n\n")
    os.exit(1)
  end

  -- 2. É um clone git?
  local inside, inside_exit = git("rev-parse --is-inside-work-tree")
  if inside_exit ~= 0 or not (inside or ""):match("true") then
    step_fail("Instalação não parece ser um clone git.")
    io.write("\n  Clone com:\n    git clone https://github.com/Sjos0/TermAI.git ~/TermAI\n\n")
    os.exit(1)
  end
  step_ok("Repositório git OK")

  -- 3. Remote origin existe?
  local _, origin_exit = git("remote get-url origin")
  if origin_exit ~= 0 then
    step_fail("Remote 'origin' não configurado")
    io.write("\n  Configure com:\n    git -C ~/TermAI remote add origin https://github.com/Sjos0/TermAI.git\n\n")
    os.exit(1)
  end

  -- 4. Working tree limpa
  local status_out, status_exit = git("status --porcelain")
  local dirty = (status_exit == 0) and status_out and status_out ~= ""

  if dirty then
    if flags.force then
      step_warn("Working tree com alterações locais (forçando com --force)")
    else
      step_fail("Working tree com alterações locais")
      io.write("\n  Arquivos modificados:\n")
      for line in (status_out or ""):gmatch("[^\n]+") do io.write("    " .. line .. "\n") end
      io.write("\n  Abortado. Remova/commite as alterações ou use:\n")
      io.write("    TermAI update --force\n\n")
      os.exit(1)
    end
  else
    step_ok("Working tree limpa")
  end
end

return M
