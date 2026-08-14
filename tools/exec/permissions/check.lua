-- tools/exec/permissions/check.lua — Verificação de permissões e modos
local config_mod = require("config")
local parser = require("agent.hooks.bash_patterns.parser")
local matcher = require("tools.exec.permissions.matcher")
local session = require("tools.exec.permissions.session")
local rules = require("tools.exec.permissions.rules")

local M = {}

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

-- Escapa uma string para uso seguro entre aspas simples em shell (evita injeção)
local function shell_quote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

-- Verifica se um nome de comando existe de fato no PATH (mesmo 'sh' usado pelo executor real).
-- Puramente informativo: nunca bloqueia nem auto-aprova, só evita que texto solto do
-- agente (ex: "Vou trazer os arquivos...") pareça uma ação legítima no diálogo de permissão.
function M.command_exists(name)
  if not name or name == "" then return true end
  local h = io.popen("command -v -- " .. shell_quote(name) .. " >/dev/null 2>&1; echo $?")
  if not h then return true end -- indisponível: não muda o comportamento atual
  local res = h:read("*l")
  h:close()
  return res == "0"
end

-- Verifica permissões para uma chamada de ferramenta/comando
-- Retorna: { allowed = boolean, reason = string, failed_sub = string|nil }
function M.check(tool_name, command)
  local mode = M.get_mode()

  -- 1. Se o modo for bypass, tudo é auto-aprovado
  if mode == "bypass" then
    return { allowed = true, reason = "Bypass de permissões ativo" }
  end

  -- 2. Se o modo for acceptEdits, auto-aceitamos edições/leituras, mas não Exec (bash)
  if mode == "acceptedits" then
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
    -- Verifica persistidos
    for _, p in ipairs(deny_rules) do
      if matcher.matches_rule(sub_trim, p) then
        return { allowed = false, reason = "deny", failed_sub = sub }
      end
    end
    -- Verifica em memória da sessão
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
      -- Verifica persistidos
      for _, p in ipairs(allow_rules) do
        if matcher.matches_rule(sub_trim, p) then
          is_allowed = true
          break
        end
      end
      -- Verifica em memória da sessão
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
        unknown_cmd = not M.command_exists(primary),
      }
    end
  end

  return { allowed = true, reason = "todos os subcomandos aprovados" }
end

return M
