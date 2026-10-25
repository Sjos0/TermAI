-- tools/exec/security/parte_2.lua — exporta: analyze.
return function(M, N)
  local config_mod = N.config_mod


  -- Função principal de análise
  function M.analyze(command)
    if not command or command == "" or command:match("^%s*$") then
      return { safe = true, warnings = {}, severity = "low" }
    end

    -- Determina nível de segurança
    local cfg = {}
    pcall(function() cfg = config_mod.load() end)

    local level = os.getenv("OPENCLAUDE_SAFETY_LEVEL")
    if not level then
      level = cfg.permissions and cfg.permissions.safetyLevel or "balanced"
    end
    level = level:lower()
    if level ~= "strict" and level ~= "balanced" and level ~= "permissive" then
      level = "balanced"
    end

    local warnings = {}

    -- Rodar validações
    local dest_warns = M.detect_destructive(command, level)
    for _, w in ipairs(dest_warns) do table.insert(warnings, w) end

    local trav_warns = M.detect_path_traversal(command, level)
    for _, w in ipairs(trav_warns) do table.insert(warnings, w) end

    local nest_warns = M.detect_nested_execution(command, level)
    for _, w in ipairs(nest_warns) do table.insert(warnings, w) end

    local inj_warns = M.detect_injection(command, level)
    for _, w in ipairs(inj_warns) do table.insert(warnings, w) end

    -- Determina severidade global
    local severity = "low"
    local safe = true

    for _, w in ipairs(warnings) do
      if w.type == "destructive" or w.type == "traversal" then
        severity = "high"
        safe = false
      elseif w.type == "nested" or w.type == "injection" then
        if severity ~= "high" then
          severity = "medium"
        end
      end
    end

    -- Em nível strict, qualquer warning médio se torna inaceitável (not safe)
    if level == "strict" and severity == "medium" then
      safe = false
    end

    return {
      safe = safe,
      warnings = warnings,
      severity = severity,
      safety_level = level
    }
  end
end
