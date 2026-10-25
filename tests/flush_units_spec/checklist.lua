-- :Render do checklist de flush (checklist.render_checklist): estados, envelope e escape idêntico ao monólito.
local harness = require("tests.helpers.harness")
local T, sec = harness.T_so_falhas, harness.sec

local M = {}

function M.run()
  -- ─────────────────────────────────────────────────────────────
  -- checklist.render_checklist
  -- ─────────────────────────────────────────────────────────────
  sec("checklist.render_checklist")

  local checklist = require("agent.flush.checklist")

  local all_false = checklist.render_checklist({
    exec = false, read = false, edit = false, done = false,
  })
  T("todos false → quatro [ ]",
    all_false:find("%[ %] exec") ~= nil
    and all_false:find("%[ %] read") ~= nil
    and all_false:find("%[ %] edit") ~= nil
    and all_false:find("%[ %] done") ~= nil
    and all_false:find("%[x%]") == nil)

  local all_true = checklist.render_checklist({
    exec = true, read = true, edit = true, done = true,
  })
  T("todos true → quatro [x]",
    all_true:find("%[x%] exec") ~= nil
    and all_true:find("%[x%] read") ~= nil
    and all_true:find("%[x%] edit") ~= nil
    and all_true:find("%[x%] done") ~= nil
    and all_true:find("%[ %]") == nil)

  local partial = checklist.render_checklist({
    exec = true, read = false, edit = true, done = false,
  })
  T("parcial: exec+edit marcados, read+done abertos",
    partial:find("%[x%] exec") ~= nil
    and partial:find("%[ %] read") ~= nil
    and partial:find("%[x%] edit") ~= nil
    and partial:find("%[ %] done") ~= nil)

  T("envelope <FLUSH_STATUS>...</FLUSH_STATUS>",
    all_false:match("^<FLUSH_STATUS>") ~= nil
    and all_false:match("</FLUSH_STATUS>$") ~= nil)

  -- Contrato de escape do monólito (main): \\n literal, NÃO newline 0x0A.
  -- Regressão residual PR #39 / análise Caçador — trava permanente.
  local expected_all_false =
    "<FLUSH_STATUS>\\n  [ ] exec  [ ] read  [ ] edit  [ ] done\\n</FLUSH_STATUS>"
  T("escape idêntico ao monólito (\\n literal, não 0x0A)",
    all_false == expected_all_false,
    "got=" .. string.format("%q", all_false))

  T("não contém newline real (0x0A) no corpo",
    all_false:find("\n", 1, true) == nil)

  T("contém o par de caracteres backslash+n",
    all_false:find("\\n", 1, true) ~= nil)
end

return M
