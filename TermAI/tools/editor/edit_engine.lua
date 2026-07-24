-- tools/editor/edit_engine.lua — Fachada do motor de edicao.
-- Conecta recovery, matcher e multi_edit.
-- Autor: Ameno | Data: 2026-05-30 | Refatoracao editor-lua

local M = {}

-- Atalho para multi_edit.replace_multi
function M.replace_multi(path, patches, read_file_fn, write_file_fn)
  local multi = require("tools.editor.edit_engine.multi_edit")
  return multi.replace_multi(path, patches, read_file_fn, write_file_fn)
end

-- Atalho para 1 edicao
function M.replace_exact(path, old_text, new_text, read_file_fn, write_file_fn)
  return M.replace_multi(path, { {old = old_text, new = new_text} }, read_file_fn, write_file_fn)
end

return M
