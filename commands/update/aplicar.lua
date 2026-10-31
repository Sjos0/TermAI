-- commands/update/aplicar.lua — passos 6 a 8: fetch, alvo (release ou main), e aplicação do update.
local N = require("commands.update.nucleo")
local c, HOME, release, run, git, short_sha, read_version, step_ok, step_fail = N.c, N.HOME, N.release, N.run, N.git, N.short_sha, N.read_version, N.step_ok, N.step_fail

local M = {}

function M.executar(flags)
  -- 6. Fetch (branch main e tags)
  local fetch_out, fetch_exit = git("fetch origin main --tags")
  if fetch_exit ~= 0 then
    step_fail("Fetch do GitHub falhou")
    io.write("\n  Não foi possível alcançar o GitHub.\n")
    io.write("  Verifique a conexão e tente de novo.\n")
    if fetch_out and fetch_out ~= "" then
      io.write(c.dim .. "  (" .. fetch_out:gsub("\n", " ") .. ")" .. c.reset .. "\n")
    end
    io.write("\n")
    os.exit(1)
  end
  step_ok("Fetch do GitHub")

  -- 7. Alvo: a última release (padrão) ou a ponta da main (--main)
  local target_ref, target_label
  if flags.main then
    target_ref, target_label = release.ref_for("main"), "main"
  else
    local body, bexit = run("curl -fsSL -m 20 https://api.github.com/repos/" .. release.REPO .. "/releases/latest")
    local tag = (bexit == 0) and release.parse_tag(body) or nil
    if not tag then
      step_fail("Nenhuma release publicada encontrada")
      io.write("\n  Use " .. c.bold .. "TermAI update --main" .. c.reset .. " para seguir a branch main.\n\n")
      os.exit(1)
    end
    -- Integridade: a release só vale se o commit da tag estiver no main.
    local tag_sha = git("rev-parse " .. tag .. "^{commit}")
    local _, anc = git("merge-base --is-ancestor " .. tag_sha .. " origin/main")
    if anc ~= 0 then
      step_fail("A release " .. tag .. " não está no main; abortando por segurança")
      os.exit(1)
    end
    target_ref, target_label = release.ref_for("release", tag), tag
  end

  local local_sha = git("rev-parse HEAD")
  local target_sha = git("rev-parse " .. target_ref .. "^{commit}")
  if not local_sha or not target_sha or local_sha == "" or target_sha == "" then
    step_fail("Não foi possível obter SHAs local/alvo")
    os.exit(1)
  end

  local old_version = read_version()
  local local_short = short_sha(local_sha)
  local target_short = short_sha(target_sha)

  if local_sha == target_sha then
    step_ok("Já está na versão mais recente (" .. target_label .. ")")
    io.write("\n  Versão: " .. old_version .. "\n  SHA:    " .. local_short .. "\n\n")
    os.exit(0)
  end

  if flags.check then
    io.write("\n  Local:  " .. old_version .. "  (" .. local_short .. ")\n")
    io.write("  Alvo:   " .. target_label .. "  (" .. target_short .. ")\n\n")
    io.write("  Há atualização disponível.\n  Rode: TermAI update\n\n")
    os.exit(0)
  end

  local log_out = git("log --oneline " .. local_sha .. ".." .. target_sha .. " | head -n 10")

  if flags.dry_run then
    step_ok("Nova versão disponível: " .. target_label)
    io.write("\n  Seria aplicado: " .. local_short .. ".." .. target_short .. "\n")
    if log_out and log_out ~= "" then
      io.write("  Commits que seriam aplicados:\n")
      for line in log_out:gmatch("[^\n]+") do io.write("    " .. line .. "\n") end
    end
    io.write("\n  (nenhum arquivo foi alterado)\n\n")
    os.exit(0)
  end

  -- 8. Aplicar: guarda o commit atual para --rollback e troca o código
  release.save_previous(HOME, local_sha)
  step_ok("Nova versão disponível: " .. target_label)
  local _, reset_exit = git("reset --hard " .. target_ref)
  if reset_exit ~= 0 then
    step_fail("Sincronização (reset --hard) falhou")
    io.write("\n  O reset não pôde ser aplicado. Verifique permissões.\n\n")
    os.exit(1)
  end
  step_ok("Código sincronizado com " .. target_label)

  local new_version = read_version()
  io.write("\n  " .. old_version .. "  →  " .. new_version .. "\n")
  io.write("  " .. local_short .. ".." .. target_short .. "\n\n")
  if log_out and log_out ~= "" then
    io.write("  Commits novos:\n")
    for line in log_out:gmatch("[^\n]+") do io.write("    " .. line .. "\n") end
    io.write("\n")
  end
  io.write("  " .. c.green .. "[OK]" .. c.reset .. "  TermAI atualizado com sucesso.\n")
  io.write("     Rode " .. c.bold .. "TermAI tui" .. c.reset .. " para usar a nova versão.\n")
  io.write("     Para voltar: " .. c.bold .. "TermAI update --rollback" .. c.reset .. "\n\n")
end

return M
