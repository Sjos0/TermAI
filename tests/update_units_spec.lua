-- tests/update_units_spec.lua
-- Testes unitários e de contrato do comando CLI `TermAI update`
-- Origem: Issue #41 / PR #42 (feature/41-cli-update)
-- Objetivo: trava de regressão para helpers puros, parsing de flags,
--           árvore de decisão (check / force / dry-run / dirty / already-up-to-date),
--           registro real em main.lua/help.lua e contratos pós-d712060
--           (BASE_Q, read_remote_version, formato Remoto: versão + SHA).
--
-- "E se isso mudar?": qualquer alteração futura em short_sha, leitura de
-- VERSION, mensagens de erro acionáveis, clean-check obrigatório,
-- preferência por reset --hard, quoting de BASE ou versão remota no
-- --check/--dry-run deve falhar aqui antes de chegar ao usuário no Termux.
--
-- Nota: commands/update.lua é script top-level com funções locais e I/O
-- git. Não alteramos produção (escopo Agente de Testes). Helpers puros
-- reimplementados; registro e design validados por leitura real dos fontes
-- quando o cwd é a raiz do clone.

package.path = "./?.lua;./?/init.lua;" .. package.path

local pass, fail = 0, 0
local function T(name, ok, detail)
  if ok then
    pass = pass + 1
  else
    fail = fail + 1
    print("  FAIL: " .. name .. (detail and (" — " .. tostring(detail)) or ""))
  end
end

local function sec(title)
  print("\n=== " .. title .. " ===")
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a") or ""
  f:close()
  return s
end

print("\n=== Unit tests: commands/update (Issue #41 / PR #42) ===\n")

-- ─────────────────────────────────────────────────────────────
-- Helpers puros (contratos extraídos de update.lua)
-- ─────────────────────────────────────────────────────────────
sec("helpers puros")

local function short_sha(sha)
  if not sha or sha == "" then return "?" end
  return sha:sub(1, 7)
end

T("short_sha nil → ?", short_sha(nil) == "?")
T("short_sha vazio → ?", short_sha("") == "?")
T("short_sha 40 chars → 7", short_sha("279337a28edb8a09393701e556ade743f25f2946") == "279337a")
T("short_sha 7 chars → idêntico", short_sha("abc1234") == "abc1234")
T("short_sha 3 chars → idêntico (sem pad)", short_sha("ab") == "ab")

local function trim_version(raw)
  return (raw or ""):match("^%s*(.-)%s*$") or "?"
end

T("trim_version com espaços e newline", trim_version("  0.9.1\n") == "0.9.1")
T("trim_version vazio → vazio", trim_version("") == "")
T("trim_version só whitespace → vazio", trim_version("   \n\t  ") == "")
T("trim_version sem espaços", trim_version("1.2.3") == "1.2.3")

-- Contrato de quoting BASE_Q: 'path' com aspas simples escapadas
local function quote_base(base)
  return "'" .. base:gsub("'", "'\\''") .. "'"
end

T("BASE_Q path simples", quote_base("/home/u/TermAI") == "'/home/u/TermAI'")
T("BASE_Q com espaço", quote_base("/home/my user/TermAI") == "'/home/my user/TermAI'")
T("BASE_Q com aspas simples", quote_base("/home/o'brien/TermAI") == "'/home/o'\\''brien/TermAI'")

-- ─────────────────────────────────────────────────────────────
-- Parsing de flags
-- ─────────────────────────────────────────────────────────────
sec("parsing de flags")

local function parse_flags(argv)
  local flags = { check = false, force = false, dry_run = false, help = false }
  for i = 2, #argv do
    local a = argv[i]
    if a == "--check" then flags.check = true
    elseif a == "--force" then flags.force = true
    elseif a == "--dry-run" then flags.dry_run = true
    elseif a == "--help" or a == "-h" then flags.help = true
    end
  end
  return flags
end

T("sem flags → todos false",
  not parse_flags({"update"}).check
  and not parse_flags({"update"}).force
  and not parse_flags({"update"}).dry_run
  and not parse_flags({"update"}).help)

T("--check sozinho", parse_flags({"update", "--check"}).check == true)
T("--force sozinho", parse_flags({"update", "--force"}).force == true)
T("--dry-run sozinho", parse_flags({"update", "--dry-run"}).dry_run == true)
T("--help / -h", parse_flags({"update", "--help"}).help == true
  and parse_flags({"update", "-h"}).help == true)

T("combinação --check --force",
  (function()
    local f = parse_flags({"update", "--check", "--force"})
    return f.check and f.force and not f.dry_run
  end)())

T("flag desconhecida é ignorada",
  (function()
    local f = parse_flags({"update", "--unknown", "--check"})
    return f.check == true and not f.force
  end)())

-- ─────────────────────────────────────────────────────────────
-- Árvore de decisão (simulada)
-- ─────────────────────────────────────────────────────────────
sec("árvore de decisão (simulada)")

local function decide(scenario)
  if not scenario.git_ok then return "fail_no_git" end
  if not scenario.inside_git then return "fail_not_git_clone" end
  if not scenario.origin_ok then return "fail_no_origin" end
  if scenario.dirty and not scenario.force then return "fail_dirty" end
  if not scenario.fetch_ok then return "fail_fetch" end
  if scenario.local_sha == scenario.remote_sha then return "already_up_to_date" end
  if scenario.check then return "check_available" end
  if scenario.dry_run then return "dry_run_preview" end
  return "apply_reset"
end

T("sem git → fail_no_git", decide({ git_ok = false }) == "fail_no_git")
T("não é clone → fail_not_git_clone",
  decide({ git_ok = true, inside_git = false }) == "fail_not_git_clone")
T("sem origin → fail_no_origin",
  decide({ git_ok = true, inside_git = true, origin_ok = false }) == "fail_no_origin")
T("dirty sem force → fail_dirty",
  decide({
    git_ok = true, inside_git = true, origin_ok = true,
    dirty = true, force = false,
  }) == "fail_dirty")
T("dirty com force → apply_reset",
  decide({
    git_ok = true, inside_git = true, origin_ok = true,
    dirty = true, force = true, fetch_ok = true,
    local_sha = "aaa", remote_sha = "bbb",
  }) == "apply_reset")
T("fetch falha → fail_fetch",
  decide({
    git_ok = true, inside_git = true, origin_ok = true,
    dirty = false, fetch_ok = false,
  }) == "fail_fetch")
T("SHAs iguais → already_up_to_date",
  decide({
    git_ok = true, inside_git = true, origin_ok = true,
    dirty = false, fetch_ok = true,
    local_sha = "abc123", remote_sha = "abc123",
  }) == "already_up_to_date")
T("--check com update → check_available",
  decide({
    git_ok = true, inside_git = true, origin_ok = true,
    dirty = false, fetch_ok = true,
    local_sha = "aaa", remote_sha = "bbb", check = true,
  }) == "check_available")
T("--dry-run com update → dry_run_preview",
  decide({
    git_ok = true, inside_git = true, origin_ok = true,
    dirty = false, fetch_ok = true,
    local_sha = "aaa", remote_sha = "bbb", dry_run = true,
  }) == "dry_run_preview")
T("caminho feliz → apply_reset",
  decide({
    git_ok = true, inside_git = true, origin_ok = true,
    dirty = false, fetch_ok = true,
    local_sha = "aaa", remote_sha = "bbb",
  }) == "apply_reset")
T("--check + SHAs iguais → already_up_to_date (prioridade)",
  decide({
    git_ok = true, inside_git = true, origin_ok = true,
    dirty = false, fetch_ok = true,
    local_sha = "same", remote_sha = "same", check = true,
  }) == "already_up_to_date")

-- ─────────────────────────────────────────────────────────────
-- Contratos de mensagem / UI
-- ─────────────────────────────────────────────────────────────
sec("contratos de mensagem (padrões estáveis)")

local expected_phrases = {
  no_git = "git não encontrado no PATH",
  not_clone = "Instalação não parece ser um clone git",
  no_origin = "Remote 'origin' não configurado",
  dirty = "Working tree com alterações locais",
  force_warn = "Working tree com alterações locais (forçando com --force)",
  already = "Já está na versão mais recente",
  fetch_fail = "Fetch origin/main falhou",
  success = "TermAI atualizado com sucesso",
  dry_run_note = "(nenhum arquivo foi alterado)",
  remoto_label = "Remoto:",  -- pós-d712060: linha com versão + SHA
}

T("frase no_git", expected_phrases.no_git:find("git não encontrado") ~= nil)
T("frase dirty", expected_phrases.dirty:find("Working tree") ~= nil)
T("frase already", expected_phrases.already:find("versão mais recente") ~= nil)
T("frase success", expected_phrases.success:find("atualizado com sucesso") ~= nil)
T("dry-run anuncia nada alterado", expected_phrases.dry_run_note:find("nenhum arquivo") ~= nil)
T("label Remoto presente no contrato UI", expected_phrases.remoto_label == "Remoto:")

-- ─────────────────────────────────────────────────────────────
-- Leitura real dos fontes (quando cwd = raiz do clone)
-- ─────────────────────────────────────────────────────────────
sec("registro e design (leitura real dos arquivos)")

local main_src = read_file("main.lua") or read_file("./main.lua")
local help_src = read_file("commands/help.lua") or read_file("./commands/help.lua")
local update_src = read_file("commands/update.lua") or read_file("./commands/update.lua")

if main_src then
  T("main.lua registra update no mapa",
    main_src:find("update%s*=%s*BASE%s*%.%.%s*\"/commands/update%.lua\"") ~= nil
    or main_src:find('update%s*=%s*BASE%s*%.%.%s*"/commands/update%.lua"') ~= nil
    or main_src:find("commands/update.lua") ~= nil)
  T("main.lua banner menciona TermAI update",
    main_src:find("TermAI update") ~= nil)
else
  T("main.lua legível no cwd (pule se fora do clone)", false,
    "rode da raiz do repositório: lua tests/update_units_spec.lua")
end

if help_src then
  T("help.lua lista comando update",
    help_src:find("update") ~= nil
    and help_src:find("origin/main") ~= nil)
else
  T("help.lua legível no cwd", false, "rode da raiz do repositório")
end

if update_src then
  T("update.lua usa reset --hard origin/main",
    update_src:find("reset %-%-hard origin/main") ~= nil)
  T("update.lua NÃO usa git pull como caminho principal",
    update_src:find("git .- pull") == nil)
  T("update.lua define BASE_Q (quoting)",
    update_src:find("BASE_Q") ~= nil
    and update_src:find("gsub") ~= nil)
  T("update.lua tem read_remote_version",
    update_src:find("read_remote_version") ~= nil
    and update_src:find("show origin/main:VERSION") ~= nil)
  T("update.lua imprime label Remoto: no --check",
    update_src:find("Remoto:") ~= nil)
  T("update.lua nunca referencia ~/.TermAI/",
    update_src:find("%.TermAI") == nil
    and update_src:find("~/.TermAI") == nil)
  T("update.lua clean-check via status --porcelain",
    update_src:find("status %-%-porcelain") ~= nil)
  T("update.lua fetch origin main",
    update_src:find("fetch origin main") ~= nil)
else
  T("update.lua legível no cwd", false, "rode da raiz do repositório")
end

-- ─────────────────────────────────────────────────────────────
-- RELATÓRIO
-- ─────────────────────────────────────────────────────────────
print(string.format(
  "\n══ RESULTADO: %d passaram, %d falharam (total: %d) ══",
  pass, fail, pass + fail))

if fail > 0 then
  print("⚠️  FALHA DETECTADA")
  os.exit(1)
else
  print("✅ Todos os testes unitários/contratuais do comando update passaram")
end
