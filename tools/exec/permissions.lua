-- tools/exec/permissions.lua — Gerenciador de permissões e regras do TermAI
local config_mod = require("config")
local parser = require("agent.hooks.bash_patterns.parser")

local M = {}

-- Permissões temporárias (em memória para a sessão atual)
local session_perms = {}
local session_denials = {}

-- SAFE_COMMANDS padrão para auto-aprovação rápida
local SAFE_COMMANDS = {
  cd = true, ls = true, echo = true, cat = true, mkdir = true,
  chmod = true, grep = true, find = true, luac = true, lua = true,
  ["lua5.4"] = true, python = true, node = true, du = true, df = true,
  uptime = true, date = true, wc = true, ps = true, tail = true,
  head = true, awk = true, clear = true, pgrep = true, test = true,
  git = true
}

-- Converte curingas de shell (ex: "sort *") para padrões Lua flexíveis e robustos
function M.wildcard_to_pattern(wildcard)
  local has_trailing_space_star = wildcard:match("%s%*$")
  if has_trailing_space_star then
    local base = wildcard:sub(1, #wildcard - 2)
    local p = base:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
    return "^" .. p .. "$"
  else
    local p = wildcard:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
    p = p:gsub("%*", ".*")
    return "^" .. p .. "$"
  end
end

-- Verifica se um comando específico bate com um padrão/regra (com ou sem curinga)
function M.matches_rule(cmd, pattern)
  cmd = cmd:lower():match("^%s*(.-)%s*$") or cmd:lower()
  pattern = pattern:lower():match("^%s*(.-)%s*$") or pattern:lower()

  if pattern == "" then return false end

  -- Se for com prefixo de dois pontos (ex: rm:*)
  local prefix = pattern:match("^(.-):%*$")
  if prefix then
    prefix = prefix:match("^%s*(.-)%s*$") or prefix
    return cmd == prefix or cmd:sub(1, #prefix + 1) == prefix .. " "
  end

  -- Se terminar com " *", tratamos o espaço e argumentos como opcionais de forma extremamente robusta
  if pattern:match("%s%*$") then
    local base = pattern:sub(1, #pattern - 2):match("^%s*(.-)%s*$")
    return cmd == base or cmd:sub(1, #base + 1) == base .. " "
  end

  if pattern:find("*", 1, true) then
    local pat = pattern:gsub("[%^%$%(%)%%%.%[%]%+%-%?]", "%%%1")
    pat = pat:gsub("%*", ".*")
    pat = "^" .. pat .. "$"
    return cmd:match(pat) ~= nil
  end

  return cmd == pattern
end

-- Retorna o modo de permissão atual (default, acceptEdits, bypass)
function M.get_mode()
  local cfg = {}
  pcall(function() cfg = config_mod.load() end)
  local mode = cfg.permissions and cfg.permissions.defaultMode or "default"
  return mode:lower()
end

-- Seta o modo de permissão (para a sessão/persistente)
function M.set_mode(mode)
  local cfg = {}
  pcall(function() cfg = config_mod.load() end)
  cfg.permissions = cfg.permissions or {}
  cfg.permissions.defaultMode = mode
  pcall(function() config_mod.save(cfg) end)
end

-- Verifica se uma ferramenta específica está bloqueada ou sempre permitida na sessão
function M.get_session_status(tool_name)
  return session_perms[tool_name]
end

-- Seta uma permissão de ferramenta específica para a sessão
function M.set_session_status(tool_name, status)
  session_perms[tool_name] = status
end

-- Verifica permissões para uma chamada de ferramenta/comando
-- Retorna: { allowed = boolean, reason = string, failed_sub = string|nil }
function M.check(tool_name, command)
  local mode = M.get_mode()

  -- 1. Se o modo for bypass, tudo é auto-aprovado
  if mode == "bypass" then
    return { allowed = true, reason = "Bypass de permissões ativo" }
  end

  -- 2. Se o modo for acceptEdits, auto-aceitamos edições/leituras, mas não exec (bash)
  if mode == "acceptedits" then
    if tool_name ~= "exec" then
      return { allowed = true, reason = "Modo acceptEdits auto-aprovou ferramenta não-bash" }
    end
  end

  -- 3. Verifica se a ferramenta inteira está bloqueada ou permitida na sessão (in-memory)
  local sess_status = session_perms[tool_name]
  if sess_status == "blocked" then
    return { allowed = false, reason = "blocked" }
  elseif sess_status == "always" then
    return { allowed = true, reason = "sempre permitido nesta sessão" }
  end

  -- 4. Verifica status persistido da ferramenta nas configurações do config.json (compatibilidade com agent/hooks/permissions)
  local cfg = {}
  pcall(function() cfg = config_mod.load() end)
  local perm_cfg = cfg.hooks and cfg.hooks.permissions and cfg.hooks.permissions[tool_name]
  if perm_cfg == "blocked" then
    return { allowed = false, reason = "blocked" }
  elseif perm_cfg == "always" then
    return { allowed = true, reason = "sempre permitido nas configurações" }
  end

  -- 5. Se não for exec, e não estiver explicitamente bloqueado/permitido, precisa de diálogo
  if tool_name ~= "exec" then
    return { allowed = false, reason = "ask" }
  end

  -- 6. Lógica de correspondência de regras de comandos bash (bashRules) para exec
  local subcommands = parser.extract_subcommands(command)
  if #subcommands == 0 then
    return { allowed = true, reason = "sem subcomandos executáveis" }
  end

  local allow_rules = cfg.bashRules and cfg.bashRules.allow or {}
  local deny_rules = cfg.bashRules and cfg.bashRules.deny or {}

  -- Adiciona as regras em memória que o usuário salvou para a sessão
  local session_allow = session_perms["bashRules_allow"] or {}
  local session_deny = session_perms["bashRules_deny"] or {}

  for _, sub in ipairs(subcommands) do
    local sub_trim = (sub:match("^%s*(.-)%s*$") or sub):lower()
    local primary = sub_trim:match("^%s*(%S+)") or ""

    -- Prioridade 1: Deny rules (sempre bloqueia)
    -- Verifica persistidos
    for _, p in ipairs(deny_rules) do
      if M.matches_rule(sub_trim, p) then
        return { allowed = false, reason = "deny", failed_sub = sub }
      end
    end
    -- Verifica em memória da sessão
    for _, p in ipairs(session_deny) do
      if M.matches_rule(sub_trim, p) then
        return { allowed = false, reason = "deny", failed_sub = sub }
      end
    end

    -- Prioridade 2: Safe commands (auto-aprovação nativa)
    local is_safe = SAFE_COMMANDS[primary] ~= nil

    -- Prioridade 3: Allow rules
    local is_allowed = false
    if not is_safe then
      -- Verifica persistidos
      for _, p in ipairs(allow_rules) do
        if M.matches_rule(sub_trim, p) then
          is_allowed = true
          break
        end
      end
      -- Verifica em memória da sessão
      if not is_allowed then
        for _, p in ipairs(session_allow) do
          if M.matches_rule(sub_trim, p) then
            is_allowed = true
            break
          end
        end
      end
    end

    -- Se não for seguro e não bater com allow rule, requer confirmação/diálogo
    if not is_safe and not is_allowed then
      return { allowed = false, reason = "ask", failed_sub = sub }
    end
  end

  return { allowed = true, reason = "todos os subcomandos aprovados" }
end

-- Registra rejeição da ferramenta ou regra para Denial Tracking
-- Retorna true se atingiu o threshold para oferecer bloqueio
function M.increment_denial(pattern_or_tool)
  session_denials[pattern_or_tool] = (session_denials[pattern_or_tool] or 0) + 1

  local cfg = {}
  pcall(function() cfg = config_mod.load() end)
  local threshold = cfg.permissions and cfg.permissions.denialThreshold or 3

  if session_denials[pattern_or_tool] >= threshold then
    session_denials[pattern_or_tool] = 0 -- reseta para a próxima vez
    return true
  end
  return false
end

-- Retorna a contagem atual de rejeições
function M.get_denial_count(pattern_or_tool)
  return session_denials[pattern_or_tool] or 0
end

-- Reseta rejeições para uma ferramenta
function M.reset_denials(pattern_or_tool)
  session_denials[pattern_or_tool] = 0
end

-- Adiciona uma regra allow/deny persistente ou temporária na sessão
function M.add_rule(pattern, behavior, persistent)
  if persistent then
    local cfg = {}
    pcall(function() cfg = config_mod.load() end)
    cfg.bashRules = cfg.bashRules or {}
    cfg.bashRules[behavior] = cfg.bashRules[behavior] or {}

    local lower = pattern:lower()
    local exists = false
    for _, p in ipairs(cfg.bashRules[behavior]) do
      if p:lower() == lower then exists = true; break end
    end
    if not exists then
      table.insert(cfg.bashRules[behavior], pattern)
      pcall(function() config_mod.save(cfg) end)
    end
  else
    local key = "bashRules_" .. behavior
    session_perms[key] = session_perms[key] or {}
    local exists = false
    local lower = pattern:lower()
    for _, p in ipairs(session_perms[key]) do
      if p:lower() == lower then exists = true; break end
    end
    if not exists then
      table.insert(session_perms[key], pattern)
    end
  end
end

-- Remove uma regra allow/deny
function M.remove_rule(pattern, behavior, persistent)
  if persistent then
    local cfg = {}
    pcall(function() cfg = config_mod.load() end)
    if cfg.bashRules and cfg.bashRules[behavior] then
      local lower = pattern:lower()
      local new_rules = {}
      for _, p in ipairs(cfg.bashRules[behavior]) do
        if p:lower() ~= lower then
          table.insert(new_rules, p)
        end
      end
      cfg.bashRules[behavior] = new_rules
      pcall(function() config_mod.save(cfg) end)
    end
  else
    local key = "bashRules_" .. behavior
    if session_perms[key] then
      local lower = pattern:lower()
      local new_rules = {}
      for _, p in ipairs(session_perms[key]) do
        if p:lower() ~= lower then
          table.insert(new_rules, p)
        end
      end
      session_perms[key] = new_rules
    end
  end
end

return M
