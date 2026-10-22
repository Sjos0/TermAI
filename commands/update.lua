-- commands/update.lua — Atualiza o clone local pela última release publicada (padrão),
-- pela branch main (--main) ou volta ao commit anterior (--rollback).
-- Issue #41 (flags), #74 (releases). Regras puras em tools/update/release.lua.

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BASE = HOME .. "/TermAI"
-- Path quotado para git -C (protege espaços e metacaracteres no HOME)
local BASE_Q = "'" .. BASE:gsub("'", "'\\''") .. "'"
local release = require("tools.update.release")

local c = {
  reset = "\27[0m",
  bold  = "\27[1m",
  dim   = "\27[2m",
  green = "\27[38;5;114m",
  red   = "\27[31m",
  cyan  = "\27[38;5;80m",
  gray  = "\27[38;5;245m",
  yellow= "\27[38;5;220m",
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

local function run(cmd)
  local h = io.popen(cmd .. " 2>&1")
  if not h then return nil, "falha ao executar: " .. cmd end
  local out = h:read("*a") or ""
  local ok, _, code = h:close()
  -- Lua 5.4: close() returns true/false, exit type, exit code
  local exit = (type(code) == "number") and code or (ok and 0 or 1)
  return out:gsub("%s+$", ""), exit
end

local function git(args) return run("git -C " .. BASE_Q .. " " .. args) end

local function short_sha(sha)
  if not sha or sha == "" then return "?" end
  return sha:sub(1, 7)
end

local function read_version()
  local f = io.open(BASE .. "/VERSION", "r")
  if not f then return "?" end
  local v = (f:read("*a") or ""):match("^%s*(.-)%s*$") or "?"
  f:close()
  return v
end

local function step_ok(msg)
  io.write("  " .. c.green .. "✓" .. c.reset .. "  " .. msg .. "\n")
end

local function step_fail(msg)
  io.write("  " .. c.red .. "✗" .. c.reset .. "  " .. msg .. "\n")
end

local function step_warn(msg)
  io.write("  " .. c.yellow .. "!" .. c.reset .. "  " .. msg .. "\n")
end

-- ---------------------------------------------------------------------------
-- Flags
-- ---------------------------------------------------------------------------

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
    return
  end
end

-- ---------------------------------------------------------------------------
-- Fluxo
-- ---------------------------------------------------------------------------

local title = flags.rollback and "Voltando à versão anterior..." or
              flags.check and "Verificando atualizações..." or
              (flags.dry_run and "Dry-run (nenhuma alteração será aplicada)" or "Atualizando TermAI...")

io.write("\n")
io.write("  " .. c.bold .. title .. c.reset .. "\n\n")

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
io.write("  " .. c.green .. "✓" .. c.reset .. "  TermAI atualizado com sucesso.\n")
io.write("     Rode " .. c.bold .. "TermAI tui" .. c.reset .. " para usar a nova versão.\n")
io.write("     Para voltar: " .. c.bold .. "TermAI update --rollback" .. c.reset .. "\n\n")
