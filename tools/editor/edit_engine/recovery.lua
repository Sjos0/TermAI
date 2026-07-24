-- tools/editor/edit_engine/recovery.lua — Tratamento de erros de edicao.
-- Detecta edicoes ja aplicadas e gera preview do arquivo para auto-correcao.
-- Copiado do OpenClaw: didEditLikelyApply + wrapEditToolWithRecovery.
-- Autor: Ameno | Data: 2026-05-30 | Refatoracao editor-lua

local M = {}

-- Verifica se a edicao ja foi aplicada (newText existe, oldText nao).
-- Copiado do OpenClaw: didEditLikelyApply()
function M.detect_already_applied(content, old_text, new_text)
  local new_exists = content:find(new_text, 1, true) ~= nil
  local old_exists = content:find(old_text, 1, true) ~= nil
  if new_exists and not old_exists then
    return true
  end
  return false
end

-- Gera mensagem de erro com preview do arquivo (800 chars ou 30 linhas).
-- Copiado do OpenClaw: wrapEditToolWithRecovery() — Classe 1 (Mismatch).
-- read_file_fn e injetado pelo editor.lua (evita dependencia circular).
function M.recovery_mismatch(path, read_file_fn)
  local content = read_file_fn(path)
  if not content then return nil end

  local preview = content:sub(1, 800)
  local line_count = 0
  local cut_pos = #preview + 1
  for i = 1, #preview do
    if preview:sub(i, i) == "\n" then
      line_count = line_count + 1
      if line_count >= 30 then cut_pos = i; break end
    end
  end
  preview = preview:sub(1, cut_pos - 1)

  local suffix = ""
  if #content > 800 then
    suffix = "\n... (" .. #content .. " caracteres totais. Use Read para ver completo.)"
  end

  return "\n\nPrimeiras linhas do arquivo atual:\n"
    .. "──────────────────────────────────\n"
    .. preview .. suffix
    .. "\n──────────────────────────────────"
    .. "\n\nUse Read para ver o arquivo e gere o oldText correto."
end

return M
