-- tools/exec/permissions/check.lua — Verificação de permissões (orquestração)
local config_mod = require("config")
local parser = require("agent.hooks.bash_patterns.parser")
local matcher = require("tools.exec.permissions.matcher")
local session = require("tools.exec.permissions.session")
local rules = require("tools.exec.permissions.rules")
local mode = require("tools.exec.permissions.mode")

local M = {}

-- Verifica permissões para uma chamada de ferramenta/comando
-- Retorna: { allowed = boolean, reason = string, failed_sub = string|nil }
function M.check(tool_name, command)
  local current_mode = mode.get()

  -- 1. Se o modo for bypass, tudo é auto-aprovado
  if current_mode == "bypass" then
    return { allowed = true, reason = "Bypass de permissões ativo" }
  end

  -- 2. Se o modo for acceptEdits, auto-aceitamos edições/leituras, mas não Exec (bash)
  if current_mode == "acceptedits" then
    if tool_name ~= "Exec" then
      return { allowed = true, reason = "Modo acceptEdits auto-aprovou ferramenta não-bash" }
    end
  end

  -- 3. Verifica se a ferramenta inteira está bloqueada ou permitida na sessão (in-memory)
  local sess_status = session.get_status(tool_name)
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

  -- 5. Se não for Exec, e não estiver explicitamente bloqueado/permitido, precisa de diálogo
  if tool_name ~= "Exec" then
    return { allowed = false, reason = "ask" }
  end

  -- 6. Lógica de correspondência de regras de comandos bash (bashRules) para Exec
  if not command or command == "" or command:match("^%s*$") then
    return { allowed = true, reason = "comando vazio ou nil" }
  end
  local subcommands = parser.extract_subcommands(command)
  if #subcommands == 0 then
    return { allowed = true, reason = "sem subcomandos executáveis" }
  end

  local allow_rules = cfg.bashRules and cfg.bashRules.allow or {}
  local deny_rules = cfg.bashRules and cfg.bashRules.deny or {}

  -- Adiciona as regras em memória que o usuário salvou para a sessão
  local session_allow = session.get_rules("allow")
  local session_deny = session.get_rules("deny")

  for _, sub in ipairs(subcommands) do
    local sub_trim = (sub:match("^%s*(.-)%s*$") or sub):lower()
    local primary = sub_trim:match("^%s*(%S+)") or ""

    -- Prioridade 1: Deny rules (sempre bloqueia)
    for _, p in ipairs(deny_rules) do
      if matcher.matches_rule(sub_trim, p) then
        return { allowed = false, reason = "deny", failed_sub = sub }
      end
    end
    for _, p in ipairs(session_deny) do
      if matcher.matches_rule(sub_trim, p) then
        return { allowed = false, reason = "deny", failed_sub = sub }
      end
    end

    -- Prioridade 2: Safe commands (auto-aprovação nativa)
    local is_safe = rules.SAFE_COMMANDS[primary] ~= nil

    -- Prioridade 3: Allow rules
    local is_allowed = false
    if not is_safe then
      for _, p in ipairs(allow_rules) do
        if matcher.matches_rule(sub_trim, p) then
          is_allowed = true
          break
        end
      end
      if not is_allowed then
        for _, p in ipairs(session_allow) do
          if matcher.matches_rule(sub_trim, p) then
            is_allowed = true
            break
          end
        end
      end
    end

    -- Se não for seguro e não bater com allow rule, requer confirmação/diálogo
    if not is_safe and not is_allowed then
      return {
        allowed = false,
        reason = "ask",
        failed_sub = sub,
        unknown_cmd = not mode.command_exists(primary),
      }
    end
  end

  return { allowed = true, reason = "todos os subcomandos aprovados" }
end

return M
