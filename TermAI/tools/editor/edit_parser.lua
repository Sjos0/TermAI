-- tools/editor/edit_parser.lua — Parser do formato merge conflict (Aider/OpenClaw).
-- Formato esperado do arg:
--   caminho/do/arquivo
--   <<<<<<< SEARCH
--   trecho antigo
--   =======
--   trecho novo
--   >>>>>>> REPLACE
-- Multiplos blocos sao suportados numa mesma chamada.
-- Autor: Ameno | Data: 2026-05-26 | Feature: Editor Refactor

local M = {}

-- Delimitadores (com tolerancia a espacos extras)
local SEARCH_MARKER  = "^%s*<+%s*SEARCH%s*$"
local SEPARATOR      = "^%s*=+%s*$"
local REPLACE_MARKER = "^%s*>+%s*REPLACE%s*$"

-- Normaliza line endings: CRLF e CR para LF
local function normalize_endlines(s)
  s = s:gsub("\r\n", "\n")
  s = s:gsub("\r", "\n")
  return s
end

-- Remove BOM UTF-8 se presente
local function strip_bom(s)
  if #s >= 3 and s:byte(1) == 0xEF and s:byte(2) == 0xBB and s:byte(3) == 0xBF then
    return s:sub(4)
  end
  return s
end

-- Divide string em linhas
local function split_lines(s)
  local lines = {}
  for line in (s .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  return lines
end

-- Verifica se uma linha bate com um pattern
local function matches(line, pattern)
  return line:match(pattern) ~= nil
end

-- Parseia o argumento completo da ferramenta Edit
-- Retorna: path (string), edits (array de {old, new}), nil
-- ou nil, nil, mensagem_de_erro
function M.parse(arg)
  -- Normalizar input
  arg = strip_bom(normalize_endlines(arg))

  -- Separar em linhas
  local lines = split_lines(arg)
  if #lines == 0 then
    return nil, nil, "Argumento vazio"
  end

  -- Primeira linha = path
  local path = lines[1]:match("^%s*(.-)%s*$")
  if path == "" then
    return nil, nil, "Caminho do arquivo nao especificado"
  end

  -- Verificar se tem pelo menos um marcador SEARCH
  local has_search = false
  for i = 2, #lines do
    if matches(lines[i], SEARCH_MARKER) then
      has_search = true
      break
    end
  end
  if not has_search then
    return nil, nil, "Formato invalido. Use:\n  caminho/do/arquivo\n  <<<<<<< SEARCH\n  trecho antigo\n  =======\n  trecho novo\n  >>>>>>> REPLACE"
  end

  -- Extrair blocos SEARCH/REPLACE
  local edits = {}
  local i = 2
  while i <= #lines do
    if matches(lines[i], SEARCH_MARKER) then
      -- Coletar oldText (ate =======)
      local old_lines = {}
      i = i + 1
      while i <= #lines and not matches(lines[i], SEPARATOR) do
        -- Verificar se encontrou outro SEARCH antes de SEPARATOR (erro)
        if matches(lines[i], SEARCH_MARKER) then
          return nil, nil, "Bloco " .. (#edits + 1) .. ": delimitador ======= ausente"
        end
        old_lines[#old_lines + 1] = lines[i]
        i = i + 1
      end

      if i > #lines then
        return nil, nil, "Bloco " .. (#edits + 1) .. ": delimitador ======= nao encontrado"
      end

      -- Pular o =======
      i = i + 1

      -- Coletar newText (ate >>>>>>> REPLACE)
      local new_lines = {}
      while i <= #lines and not matches(lines[i], REPLACE_MARKER) do
        new_lines[#new_lines + 1] = lines[i]
        i = i + 1
      end

      if i > #lines then
        return nil, nil, "Bloco " .. (#edits + 1) .. ": delimitador >>>>>>> REPLACE nao encontrado"
      end

      -- Montar old e new
      local old_text = table.concat(old_lines, "\n")
      local new_text = table.concat(new_lines, "\n")

      -- Detecta range de linhas (ex: "10-15" ou "42")
      local trimmed = old_text:match("^%s*(.-)%s*$") or ""
        local ls, le = trimmed:match("^[Ll]?(%d+)%-[Ll]?(%d+)$")
      if not ls then
          local s = trimmed:match("^[Ll]?(%d+)$")
        if s then ls, le = s, s end
      end
      if ls then
        edits[#edits + 1] = { type = "lines", ls = tonumber(ls), le = tonumber(le), new = new_text }
      else
        if trimmed == "" then
          return nil, nil, "Bloco " .. (#edits + 1) .. ": texto antigo nao pode estar vazio"
        end
        edits[#edits + 1] = { old = old_text, new = new_text }
      end

      -- Pular >>>>>>> REPLACE
      i = i + 1
    else
      -- Linha entre blocos ou apos o ultimo bloco — ignorar
      i = i + 1
    end
  end

  if #edits == 0 then
    return nil, nil, "Nenhum bloco de edicao valido encontrado"
  end

  return path, edits, nil
end

return M
