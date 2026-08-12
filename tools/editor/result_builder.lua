-- tools/editor/result_builder.lua — Monta a string de resultado final do Edit.
-- Combina mensagem de sucesso + diff (se houver) + file_info + validação lua.
local diff_builder = require("tools.editor.diff_builder")
local M = {}

local function should_diff(msg)
  return msg ~= nil and (
       msg:match("^Substituicao aplicada") ~= nil
    or msg:match("^Substituição aplicada") ~= nil
    or msg:match("^Replacement applied") ~= nil)
end

function M.build(path, msg, edits, before_content, file_info_fn, luac_val_fn)
  local diff, added_count, removed_count
  if should_diff(msg) then
    diff, added_count, removed_count = diff_builder.build(before_content, edits)
  end

  local f = io.open(path, "r")
  local info = ""
  if f then local c = f:read("*a"); f:close(); info = "\n" .. file_info_fn(c) end
  local luac_msg = luac_val_fn(path)

  local out = msg or "Replacement applied"
  local is_zero_change = before_content and before_content ~= "" and should_diff(msg) and (added_count == 0 or not added_count) and (removed_count == 0 or not removed_count)

  -- Veto de segurança: se o motor reportou sucesso mas nada foi alterado, força erro
  if is_zero_change then
    out = "❌ Erro: Nenhuma alteração foi realizada no arquivo. O bloco 'old_text' de busca ou o intervalo de linhas enviado não correspondem a nenhuma alteração de conteúdo."
  end

  if diff or is_zero_change then
    out = out .. "\nMETRICS: added=" .. (added_count or 0) .. ", removed=" .. (removed_count or 0)
    if diff then out = out .. "\n" .. diff end
  end
  out = out .. info
  if luac_msg then out = out .. "\n" .. luac_msg end
  return out
end

return M
