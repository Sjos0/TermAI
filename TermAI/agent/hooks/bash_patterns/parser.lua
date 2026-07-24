-- agent/hooks/bash_patterns/parser.lua — Parsing de pipelines, subshells,
-- heredocs e curingas.
local M = {}

-- Converte um padrão curinga de shell (ex: "git commit *") em um Lua Pattern seguro
function M.wildcard_to_pattern(wildcard)
  local p = wildcard:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
  p = p:gsub("%*", ".*")
  return "^" .. p .. "$"
end

-- Detecta delimitador de heredoc em uma string que começa logo após "<<".
-- Retorna o delimitador e seu comprimento, ou nil se não encontrar.
local function find_heredoc_delim(str)
  local delim = str:match("^%s*['\"]?(%S+)['\"]?")
  if delim and #delim > 0 and #delim <= 256 then
    return delim, #delim
  end
  return nil, 0
end

-- Extrai subcomandos com lexer consciente de aspas e heredocs
-- (Quote-Aware State Machine + Heredoc-Aware)
function M.extract_subcommands(cmd)
  local subcmds = {}

  -- 1. Captura conteúdo de subshells $(...) ou `...`
  for sub in cmd:gmatch("%$%((.-)%)") do
    if sub ~= "" then subcmds[#subcmds+1] = sub end
  end
  for sub in cmd:gmatch("`(.-)`") do
    if sub ~= "" then subcmds[#subcmds+1] = sub end
  end

  -- Remove subshells do comando principal para evitar dupla análise
  local main_cmd = cmd:gsub("%$%((.-)%)", ""):gsub("`(.-)`", "")

  -- 2. Escaneia caractere por caractere respeitando aspas e heredocs
  local len = #main_cmd
  local i = 1
  local in_single = false
  local in_double = false
  local current_part = {}
  local in_heredoc = false
  local heredoc_delim = nil

  local function flush_part()
    if #current_part == 0 then return end
    local part_str = table.concat(current_part)
    local trimmed = part_str:match("^%s*(.-)%s*$")
    if trimmed and trimmed ~= "" then
      -- Não remove << (heredoc) — só redirecionamentos simples
      local clean = trimmed:gsub("[>]+.*$", ""):match("^%s*(.-)%s*$")
      if clean and clean ~= "" then
        subcmds[#subcmds+1] = clean
      end
    end
    current_part = {}
  end

  while i <= len do
    local char = main_cmd:sub(i, i)
    local next_char = main_cmd:sub(i+1, i+1)

    if in_heredoc then
      -- Dentro de heredoc: pula tudo até delimitador em linha própria
      if char == "\n" then
        local rest = main_cmd:sub(i + 1)
        local line = rest:match("^[^\n]*")
        if line and line:match("^" .. heredoc_delim .. "$") then
          -- Delimitador encontrado (exato, sem aspas)
          i = i + #line + 1
          in_heredoc = false
          heredoc_delim = nil
          current_part = {}
        end
        -- Se não é o delimitador, pula a linha (conteúdo do heredoc)
      end
    elseif char == "\\" then
      current_part[#current_part+1] = char
      if next_char ~= "" then
        current_part[#current_part+1] = next_char
        i = i + 1
      end
    elseif char == "'" and not in_double then
      in_single = not in_single
      current_part[#current_part+1] = char
    elseif char == '"' and not in_single then
      in_double = not in_double
      current_part[#current_part+1] = char
    elseif not in_single and not in_double then
      if char == ";" or char == "\n" then
        flush_part()
      elseif char == "|" then
        if next_char == "|" then
          flush_part()
          i = i + 1
        else
          flush_part()
        end
      elseif char == "&" and next_char == "&" then
        flush_part()
        i = i + 1
      elseif char == "<" and next_char == "<" then
        -- Detecta heredoc (<< ou <<-)
        local rest_after = main_cmd:sub(i + 2)
        local delim, delim_len = find_heredoc_delim(rest_after)
        if delim then
          in_heredoc = true
          heredoc_delim = delim
          i = i + 1 + 1 + delim_len  -- pula << + delimiter
          -- Pula até o \n que inicia o conteúdo (se houver)
          while i <= len and main_cmd:sub(i, i) ~= "\n" do
            i = i + 1
          end
          -- Não incrementa i aqui — o \n será processado no próximo passo
        else
          -- << sem delimitador válido — trata como redirect normal
          current_part[#current_part+1] = char
        end
      else
        current_part[#current_part+1] = char
      end
    else
      current_part[#current_part+1] = char
    end
    i = i + 1
  end
  flush_part()

  return subcmds
end

return M
