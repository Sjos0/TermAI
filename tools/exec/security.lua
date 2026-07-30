-- tools/exec/security.lua — Análise de segurança para comandos bash
local config_mod = require("config")

local M = {}

-- Comandos destrutivos a serem detectados
local DESTRUCTIVE_PATTERNS = {
  { pattern = "%f[%w]rm%f[%W]%s+%-rf", message = "Comando 'rm -rf' (remoção recursiva forçada) detectado" },
  { pattern = "%f[%w]rmdir%f[%W]", message = "Comando 'rmdir' detectado" },
  { pattern = "%f[%w]mkfs%f[%W]", message = "Comando 'mkfs' (formatação de sistema de arquivos) detectado" },
  { pattern = "%f[%w]dd%f[%W]", message = "Comando 'dd' (escrita direta em disco/partição) detectado" },
  { pattern = "%f[%w]shutdown%f[%W]", message = "Comando de desligamento ('shutdown') detectado" },
  { pattern = "%f[%w]reboot%f[%W]", message = "Comando de reinicialização ('reboot') detectado" },
  { pattern = "%f[%w]shred%f[%W]", message = "Comando 'shred' (destruição de arquivos) detectado" }
}

-- Padrões de escape e injeção de shell
local INJECTION_PATTERNS = {
  { char = ";", type = "semicolon", message = "Ponto e vírgula ';' detectado (encadeamento de comandos)" },
  { char = "|", type = "pipe", message = "Pipe '|' ou ou-lógico '||' detectado" },
  { char = "&", type = "ampersand", message = "E-comercial '&' ou e-lógico '&&' detectado" }
}

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

return M
