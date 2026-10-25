-- agent/hooks/bash_patterns/parser/parte_1.lua — exporta: wildcard_to_pattern, strip_leading_assignments.
return function(M, N)
  local find_assignment_value_end = N.find_assignment_value_end


  -- Converte um padrão curinga de shell (ex: "git commit *") em um Lua Pattern seguro
  function M.wildcard_to_pattern(wildcard)
    local p = wildcard:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
    p = p:gsub("%*", ".*")
    return "^" .. p .. "$"
  end


  -- Remove atribuições de variáveis no início de um subcomando (ex: VAR=value)
  function M.strip_leading_assignments(subcmd)
    local s = subcmd:match("^%s*(.-)%s*$") or ""
    while true do
      local var_name = s:match("^([a-zA-Z_][a-zA-Z0-9_]*)=")
      if not var_name then
        break
      end
      local start_pos = #var_name + 2 -- tamanho da variável + '=' + 1
      local end_pos = find_assignment_value_end(s, start_pos)
      s = s:sub(end_pos + 1):match("^%s*(.-)%s*$") or ""
    end
    return s
  end
end
