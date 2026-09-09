-- agent/flush/checklist.lua — FPM ChecklistRenderer: gera XML <FLUSH_STATUS> com checkmarks.
-- Contrato de string alinhado ao monólito em main: \\n literal (não newline 0x0A).
-- Ver regressão residual documentada em PR #39 (análise Caçador).
local M = {}

--- Gera o XML <FLUSH_STATUS> com checkmarks do protocolo.
-- @param fs table flush_state {exec, read, edit, done}
-- @return string Bloco XML para injeção no prompt
--   O separador entre tags e o corpo é o par de caracteres '\\'+'n'
--   (backslash + n), idêntico ao render_checklist do monólito.
function M.render_checklist(fs)
  local x = "[x]"
  local o = "[ ]"
  return string.format("<FLUSH_STATUS>\\n  %s exec  %s read  %s edit  %s done\\n</FLUSH_STATUS>",
    fs.exec and x or o, fs.read and x or o, fs.edit and x or o, fs.done and x or o)
end

return M
