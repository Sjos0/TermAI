-- :Parsing de flags do update e árvore de decisão simulada (check, force, dry-run, dirty, already-up-to-date).
local harness = require("tests.helpers.harness")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
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
end

return M
