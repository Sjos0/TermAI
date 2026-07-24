-- tools/editor/edit_engine/matcher.lua — Fuzzy match progressivo (2 estagios).
-- Aplica uma edicao com exact match ou fuzzy normalizado.
-- Copiado do OpenClaw: search-and-replace com 2 camadas.
-- Autor: Ameno | Data: 2026-05-30 | Refatoracao editor-lua

local norm = require("tools.editor.normalizer")
local recovery = require("tools.editor.edit_engine.recovery")

local M = {}

-- Aplica uma edicao com fuzzy match progressivo (2 estagios).
-- Retorna: ok (bool), msg (string), new_content (string), fuzzy_used (bool)
function M.apply_one(content, old_text, new_text, patch_num)
  local label = patch_num and (" [patch " .. patch_num .. "]") or ""

  -- oldText vazio -> erro
  if old_text:match("^%s*$") then
    return false, "texto antigo vazio" .. label, nil, false
  end

  -- ESTAGIO 1: Exact Match (busca literal, sem normalizacao)
  local first = content:find(old_text, 1, true)
  if first then
    -- Verificar unicidade
    local second = content:find(old_text, first + #old_text, true)
    if second then
      return false, "trecho aparece mais de uma vez" .. label
        .. " - use um trecho maior para ser unico", nil, false
    end
    -- Aplicar substituicao
    local new_content = content:sub(1, first - 1)
      .. new_text
      .. content:sub(first + #old_text)
    return true, "ok", new_content, false
  end

  -- ESTAGIO 2: Fuzzy Match (busca normalizada)
  local content_fuzzy = norm.normalize_all(content)
  local old_fuzzy     = norm.normalize_all(old_text)
  local new_fuzzy     = norm.normalize_all(new_text)

  local first_fuzzy = content_fuzzy:find(old_fuzzy, 1, true)

  if not first_fuzzy then
    -- Verificar se edicao ja foi aplicada
    if recovery.detect_already_applied(content, old_text, new_text) then
      return true, "Edicao ja aplicada (detectada)", content, false
    end
    return false, "trecho nao encontrado" .. label
      .. " - verifique espacos, aspas e quebras de linha", nil, false
  end

  -- Verificar unicidade no espaco fuzzy
  local second_fuzzy = content_fuzzy:find(old_fuzzy, first_fuzzy + #old_fuzzy, true)
  if second_fuzzy then
    return false, "trecho aparece mais de uma vez" .. label
      .. " (mesmo apos normalizacao)", nil, true
  end

  -- Aplicar substituicao no espaco fuzzy
  local new_content = content_fuzzy:sub(1, first_fuzzy - 1)
    .. new_fuzzy
    .. content_fuzzy:sub(first_fuzzy + #old_fuzzy)

  return true, "ok (fuzzy)", new_content, true
end

return M
