-- commands/update.lua — Sincroniza o clone local com origin/main
-- Issue #41: TermAI update [--check] [--force] [--dry-run]

local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BASE = HOME .. "/TermAI"
-- Path quotado para git -C (protege espaços e metacaracteres no HOME)
local BASE_Q = "'" .. BASE:gsub("'", "'\\''") .. "'"

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

-- Lê VERSION do tip remoto (após fetch). Fallback "?" se o arquivo não existir.
local function read_remote_version()
  local out, exit = run("git -C " .. BASE_Q .. " show origin/main:VERSION")
  if exit ~= 0 or not out or out == "" then return "?" end
  return (out:match("^%s*(.-)%s*$") or "?")
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

local flags = { check = false, force = false, dry_run = false }
for i = 2, #arg do
  local a = arg[i]
  if a == "--check" then flags.check = true
  elseif a == "--force" then flags.force = true
  elseif a == "--dry-run" then flags.dry_run = true
  elseif a == "--help" or a == "-h" then
    io.write("\n")
    io.write(c.bold .. "  TermAI update" .. c.reset .. " — sincroniza o clone local com origin/main\n\n")
    io.write("  Uso:\n")
    io.write("    TermAI update           Atualiza para origin/main\n")
    io.write("    TermAI update --check   Só verifica se há atualização\n")
    io.write("    TermAI update --dry-run Mostra o que seria feito sem alterar\n")
    io.write("    TermAI update --force   Ignora working tree suja e força reset\n\n")
    return
  end
end

-- ---------------------------------------------------------------------------
-- Fluxo
-- ---------------------------------------------------------------------------

local title = flags.check and "Verificando atualizações..." or
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
local inside, inside_exit = run("git -C " .. BASE_Q .. " rev-parse --is-inside-work-tree")
if inside_exit ~= 0 or not (inside or ""):match("true") then
  step_fail("Instalação não parece ser um clone git.")
  io.write("\n  Reinstale com:\n    git clone https://github.com/Sjos0/TermAI.git ~/TermAI\n\n")
  os.exit(1)
end
step_ok("Repositório git OK")

-- 3. Remote origin existe?
local _, origin_exit = run("git -C " .. BASE_Q .. " remote get-url origin")
if origin_exit ~= 0 then
  step_fail("Remote 'origin' não configurado")
  io.write("\n  Configure com:\n    git -C ~/TermAI remote add origin https://github.com/Sjos0/TermAI.git\n\n")
  os.exit(1)
end

-- 4. Clean check
local status_out, status_exit = run("git -C " .. BASE_Q .. " status --porcelain")
local dirty = (status_exit == 0) and status_out and status_out ~= ""

if dirty then
  if flags.force then
    step_warn("Working tree com alterações locais (forçando com --force)")
  else
    step_fail("Working tree com alterações locais")
    io.write("\n  Arquivos modificados:\n")
    for line in (status_out or ""):gmatch("[^\n]+") do
      io.write("    " .. line .. "\n")
    end
    io.write("\n  Abortado. Remova/commite as alterações ou use:\n")
    io.write("    TermAI update --force\n\n")
    os.exit(1)
  end
else
  step_ok("Working tree limpa")
end

-- 5. Fetch
local fetch_out, fetch_exit = run("git -C " .. BASE_Q .. " fetch origin main")
if fetch_exit ~= 0 then
  step_fail("Fetch origin/main falhou")
  io.write("\n  Não foi possível alcançar o GitHub.\n")
  io.write("  Verifique a conexão e tente de novo.\n")
  if fetch_out and fetch_out ~= "" then
    io.write(c.dim .. "  (" .. fetch_out:gsub("\n", " ") .. ")" .. c.reset .. "\n")
  end
  io.write("\n")
  os.exit(1)
end
step_ok("Fetch origin/main")

-- 6. Comparar SHAs
local local_sha, local_exit = run("git -C " .. BASE_Q .. " rev-parse HEAD")
local remote_sha, remote_exit = run("git -C " .. BASE_Q .. " rev-parse origin/main")

if local_exit ~= 0 or remote_exit ~= 0 or not local_sha or not remote_sha then
  step_fail("Não foi possível obter SHAs local/remoto")
  os.exit(1)
end

local old_version = read_version()
local local_short = short_sha(local_sha)
local remote_short = short_sha(remote_sha)

if local_sha == remote_sha then
  step_ok("Já está na versão mais recente")
  io.write("\n")
  io.write("  Versão: " .. old_version .. "\n")
  io.write("  SHA:    " .. local_short .. "\n\n")
  if flags.check then
    io.write("  Já está atualizado.\n\n")
  else
    io.write("  Nada a fazer.\n\n")
  end
  os.exit(0)
end

-- Há atualização — versão remota disponível após fetch
local remote_version = read_remote_version()

if flags.check then
  -- Só reporta; não aplica (mockup da issue: Local + Remoto com versão e SHA)
  io.write("\n")
  io.write("  Local:  " .. old_version .. "  (" .. local_short .. ")\n")
  io.write("  Remoto: " .. remote_version .. "  (" .. remote_short .. ")\n\n")
  io.write("  Há atualização disponível.\n")
  io.write("  Rode: TermAI update\n\n")
  os.exit(0)
end

if flags.dry_run then
  step_ok("Nova versão disponível")
  io.write("\n")
  io.write("  Seria aplicado:\n")
  io.write("    " .. old_version .. " → " .. remote_version .. "\n")
  io.write("    " .. local_short .. ".." .. remote_short .. "\n\n")
  -- Log resumido
  local log_out = run("git -C " .. BASE_Q .. " log --oneline " .. local_sha .. ".." .. remote_sha .. " | head -n 10")
  if log_out and log_out ~= "" then
    io.write("  Commits que seriam aplicados:\n")
    for line in log_out:gmatch("[^\n]+") do
      io.write("    " .. line .. "\n")
    end
    io.write("\n")
  end
  io.write("  (nenhum arquivo foi alterado)\n\n")
  os.exit(0)
end

-- 7. Aplicar reset --hard
step_ok("Nova versão disponível")
local _, reset_exit = run("git -C " .. BASE_Q .. " reset --hard origin/main")
if reset_exit ~= 0 then
  step_fail("Código sincronizado (reset --hard) falhou")
  io.write("\n  O reset não pôde ser aplicado. Verifique permissões.\n\n")
  os.exit(1)
end
step_ok("Código sincronizado (reset --hard)")

-- 8. Pós-update
local new_version = read_version()
io.write("\n")
io.write("  " .. old_version .. "  →  " .. new_version .. "\n")
io.write("  " .. local_short .. ".." .. remote_short .. "\n\n")

local log_out = run("git -C " .. BASE_Q .. " log --oneline " .. local_sha .. ".." .. remote_sha .. " | head -n 10")
if log_out and log_out ~= "" then
  io.write("  Commits novos:\n")
  for line in log_out:gmatch("[^\n]+") do
    io.write("    " .. line .. "\n")
  end
  io.write("\n")
end

io.write("  " .. c.green .. "✓" .. c.reset .. "  TermAI atualizado com sucesso.\n")
io.write("     Rode " .. c.bold .. "TermAI tui" .. c.reset .. " para usar a nova versão.\n\n")
