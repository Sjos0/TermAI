-- agent/hooks/bash_patterns/parser/nucleo_1.lua — helpers internos: is_real_subcommand, find_heredoc_delim, find_assignment_value_end.
return function(M)
  local P = require("agent.hooks.bash_patterns.parser.nucleo")(M)


  local function is_real_subcommand(s)
    return s ~= "" and s:match("%w") ~= nil
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


  -- Encontra o fim do valor de uma atribuição de variável considerando aspas
  local function find_assignment_value_end(str, start_pos)
    local len = #str
    local i = start_pos
    local in_single = false
    local in_double = false
    while i <= len do
      local char = str:sub(i, i)
      local next_char = str:sub(i+1, i+1)
      if char == "\\" then
        if next_char ~= "" then
          i = i + 1
        end
      elseif char == "'" and not in_double then
        in_single = not in_single
      elseif char == '"' and not in_single then
        in_double = not in_double
      elseif not in_single and not in_double then
        -- Caractere não citado: verifica se é um terminador (espaço ou controle do shell)
        if char:match("%s") or char == ";" or char == "&" or char == "|" or char == "<" or char == ">" or char == "(" or char == ")" then
          return i - 1
        end
      end
      i = i + 1
    end
    return len
  end
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.is_real_subcommand = is_real_subcommand
  N.find_heredoc_delim = find_heredoc_delim
  N.find_assignment_value_end = find_assignment_value_end
  return N
end
