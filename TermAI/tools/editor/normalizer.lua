-- tools/editor/normalizer.lua — Normalização de texto para busca fuzzy.
-- Remove diferenças invisíveis (BOM, CRLF, smart quotes, dashes, NBSP)
-- que fazem string.find() falhar silenciosamente.
-- Copiado do OpenClaw, adaptado para Lua/Termux.
-- Autor: Ameno | Data: 2026-05-26 | Feature: Editor Refactor — Spec 02

local M = {}

-- Remove BOM UTF-8 (bytes EF BB BF) do início do conteúdo.
-- Retorna: conteúdo sem BOM, booleano (true se tinha BOM)
function M.strip_bom(content)
  if #content >= 3
    and content:byte(1) == 0xEF
    and content:byte(2) == 0xBB
    and content:byte(3) == 0xBF then
    return content:sub(4), true
  end
  return content, false
end

-- Normaliza line endings: CRLF (\r\n) e CR (\r) solto → LF (\n).
-- Preciso vir ANTES de qualquer busca para garantir consistência.
function M.normalize_line_endings(content)
  content = content:gsub("\r\n", "\n")
  content = content:gsub("\r", "\n")
  return content
end

-- Detecta qual line ending o arquivo original usa.
-- Retorna "\r\n" ou "\n". Usado para restaurar após edição.
function M.detect_line_ending(content)
  if content:find("\r\n", 1, true) then return "\r\n" end
  return "\n"
end

-- Remove trailing whitespace (espaços no fim de cada linha).
-- Resolve o bug mais comum: IA gera oldText com espaço extra no fim.
function M.normalize_whitespace(content)
  -- Trailing spaces antes de newline
  content = content:gsub(" +\n", "\n")
  -- Trailing spaces no fim do arquivo (última linha)
  content = content:gsub(" +$", "")
  return content
end

-- Converte caracteres Unicode problemáticos para ASCII equivalente.
-- Smart quotes, dashes, espaços especiais — a IA gera esses
-- caracteres frequentemente mas o arquivo pode ter ASCII puro.
function M.normalize_unicode(content)
  -- Smart quotes → aspas retas
  content = content:gsub("\xE2\x80\x98", "'")   -- ' esquerda (U+2018)
  content = content:gsub("\xE2\x80\x99", "'")   -- ' direita (U+2019)
  content = content:gsub("\xE2\x80\x9C", '"')   -- " esquerda (U+201C)
  content = content:gsub("\xE2\x80\x9D", '"')   -- " direita (U+201D)

  -- Dashes Unicode → hífen ASCII
  content = content:gsub("\xE2\x80\x93", "-")   -- en-dash (U+2013)
  content = content:gsub("\xE2\x80\x94", "-")   -- em-dash (U+2014)
  content = content:gsub("\xE2\x80\x92", "-")   -- figure dash (U+2012)

  -- Espaços especiais → espaço regular
  content = content:gsub("\xC2\xA0", " ")        -- NBSP (U+00A0)
  content = content:gsub("\xE2\x80\xAF", " ")    -- narrow NBSP (U+202F)
  content = content:gsub("\xE3\x80\x80", " ")    -- ideographic space (U+3000)

  return content
end

-- Aplica TODAS as normalizações em sequência.
-- Retorna: conteúdo normalizado, booleano (true se tinha BOM)
-- Usado como "fingerprint" para busca fuzzy.
function M.normalize_all(content)
  local had_bom
  content, had_bom = M.strip_bom(content)
  content = M.normalize_line_endings(content)
  content = M.normalize_unicode(content)
  content = M.normalize_whitespace(content)
  return content, had_bom
end

-- Restaura o formato original após edição no espaço normalizado.
-- Se o arquivo tinha BOM → devolve o BOM.
-- Se o arquivo tinha CRLF → converte LF de volta para CRLF.
-- Usado DEPOIS de aplicar todas as edições.
function M.restore_format(content, had_bom, original_ending)
  if original_ending == "\r\n" then
    content = content:gsub("\n", "\r\n")
  end
  if had_bom then
    content = "\xEF\xBB\xBF" .. content
  end
  return content
end

return M
