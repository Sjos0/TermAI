-- commands/update/rollback.lua — passo 5: volta ao commit guardado pelo último update (sempre encerra o processo).
local N = require("commands.update.nucleo")
local c, HOME, release, git, short_sha, read_version, step_ok, step_fail = N.c, N.HOME, N.release, N.git, N.short_sha, N.read_version, N.step_ok, N.step_fail

local M = {}

function M.executar(flags)
  -- 5. Rollback: volta ao commit guardado pelo último update
  if flags.rollback then
    local prev = release.read_previous(HOME)
    if not prev then
      step_fail("Não há versão anterior registrada (rode um update antes).")
      io.write("\n")
      os.exit(1)
    end
    local local_sha = git("rev-parse HEAD")
    if flags.dry_run then
      step_ok("Voltaria para " .. short_sha(prev))
      io.write("\n  (nenhum arquivo foi alterado)\n\n")
      os.exit(0)
    end
    local _, rc = git("reset --hard " .. prev)
    if rc ~= 0 then
      step_fail("Rollback falhou (reset --hard)")
      os.exit(1)
    end
    release.save_previous(HOME, local_sha)   -- desfazer o rollback é possível de novo
    step_ok("Voltou para " .. short_sha(prev))
    io.write("\n  " .. c.bold .. "Versão: " .. read_version() .. c.reset .. "\n\n")
    os.exit(0)
  end
end

return M
