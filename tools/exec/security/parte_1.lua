-- tools/exec/security/parte_1.lua — exporta: detect_injection, detect_path_traversal, detect_destructive, detect_nested_execution.
return function(M, N)
  local DESTRUCTIVE_PATTERNS, INJECTION_PATTERNS = N.DESTRUCTIVE_PATTERNS, N.INJECTION_PATTERNS


  -- Comandos destrutivos a serem detectados

  -- Padrões de escape e injeção de shell

  -- Detecta injeção de comandos (metacaracteres shell)
  function M.detect_injection(command, level)
    local warnings = {}

    -- Se permissive, relaxamos avisos gerais sobre caracteres comuns se não houver um comando perigoso
    if level == "permissive" then
      return warnings
    end

    for _, inj in ipairs(INJECTION_PATTERNS) do
      if string.find(command, inj.char, 1, true) then
        -- Verifica se é || ou &&
        if inj.char == "|" then
          if command:find("||", 1, true) then
            table.insert(warnings, { type = "injection", pattern = "||", message = "Operador lógico '||' detectado" })
          else
            table.insert(warnings, { type = "injection", pattern = "|", message = inj.message })
          end
        elseif inj.char == "&" then
          if command:find("&&", 1, true) then
            table.insert(warnings, { type = "injection", pattern = "&&", message = "Operador lógico '&&' detectado" })
          else
            table.insert(warnings, { type = "injection", pattern = "&", message = inj.message })
          end
        else
          table.insert(warnings, { type = "injection", pattern = inj.char, message = inj.message })
        end
      end
    end

    return warnings
  end


  -- Detecta path traversal e acesso a diretórios sensíveis
  function M.detect_path_traversal(command, level)
    local warnings = {}

    if string.find(command, "../", 1, true) then
      table.insert(warnings, { type = "traversal", pattern = "../", message = "Path traversal '../' detectado" })
    end

    -- Paths absolutos sensíveis
    local sensitive_paths = {
      "/etc/passwd", "/etc/shadow", "/etc/sudoers", "/etc/hosts",
      "/data/data/com.termux/files/usr/etc", "/proc/sys", "/dev/mem", "/dev/kmem"
    }

    for _, path in ipairs(sensitive_paths) do
      if string.find(command, path, 1, true) then
        table.insert(warnings, { type = "traversal", pattern = path, message = "Acesso a caminho de sistema sensível '" .. path .. "' detectado" })
      end
    end

    return warnings
  end


  -- Detecta comandos destrutivos
  function M.detect_destructive(command, level)
    local warnings = {}
    local cmd_lower = command:lower()

    for _, dest in ipairs(DESTRUCTIVE_PATTERNS) do
      if cmd_lower:match(dest.pattern) then
        table.insert(warnings, { type = "destructive", pattern = dest.pattern, message = dest.message })
      end
    end

    return warnings
  end


  -- Detecta execução aninhada (backticks ou $())
  function M.detect_nested_execution(command, level)
    local warnings = {}

    -- Backticks
    if string.find(command, "`", 1, true) then
      table.insert(warnings, { type = "nested", pattern = "`", message = "Execução aninhada usando crases (backticks) detectada" })
    end

    -- Subshell $(...)
    if command:match("%$%b()") then
      table.insert(warnings, { type = "nested", pattern = "$()", message = "Execução aninhada usando '$()' detectada" })
    end

    return warnings
  end
end
