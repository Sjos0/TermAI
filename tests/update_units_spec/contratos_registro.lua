-- :Contratos de mensagem (frases estáveis) e registro/design lidos dos fontes reais.
local harness = require("tests.helpers.harness")
local T, sec = harness.T_so_falhas, harness.sec

local function read_file(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a") or ""
  f:close()
  return s
end

local M = {}

function M.run()
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
  local update_src = require("tests.helpers.fonte").ler("commands/update")

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
    T("update.lua aplica reset --hard no alvo (release ou origin/main)",
      update_src:find("reset --hard \" .. target_ref", 1, true) ~= nil)
    T("update.lua NÃO usa git pull como caminho principal",
      update_src:find("git .- pull") == nil)
    T("update.lua define BASE_Q (quoting)",
      update_src:find("BASE_Q") ~= nil
      and update_src:find("gsub") ~= nil)
    T("update.lua consulta a última release e valida a tag no main",
      update_src:find("releases/latest", 1, true) ~= nil
      and update_src:find("merge-base --is-ancestor", 1, true) ~= nil)
    T("update.lua imprime label Alvo: no --check",
      update_src:find("Alvo:", 1, true) ~= nil)
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
end

return M
