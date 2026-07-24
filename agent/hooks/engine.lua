-- agent/hooks/engine.lua — Motor central de eventos do sistema de Hooks.
-- Gerencia: PreToolUse, PostToolUse, OnAgentStop, OnMemoryFlush.
-- Suporta scripts do usuário (.lua e .sh) em ~/.TermAI/hooks/<Evento>/

local M = {}

local HOME      = os.getenv("HOME") or "/data/data/com.termux/files/home"
local HOOKS_DIR = HOME .. "/.TermAI/hooks"

-- ── Dispatcher principal ──────────────────────────────────────────────────
-- PreToolUse retorna: allowed (bool), reason (string|nil)
-- Demais eventos: sem retorno significativo.
function M.run(event, ...)
  if event == "PreToolUse" then
    local tool_name, tool_arg = ...
    local allowed, reason = M._pre_tool_use(tool_name, tool_arg)
    M._run_user_scripts(event, tool_name, tool_arg)
    return allowed, reason

  elseif event == "PostToolUse" then
    local tool_name, tool_arg, result = ...
    M._run_user_scripts(event, tool_name, tool_arg, result)

  elseif event == "OnAgentStop" then
    M._run_user_scripts(event, ...)

  elseif event == "OnMemoryFlush" then
    M._run_user_scripts(event, ...)
  end
end

-- ── PreToolUse ─────────────────────────────────────────────────────────────
function M._pre_tool_use(tool_name, tool_arg)
  -- YOLO Mode: bypass total de segurança (estilo OpenClaude fullAccess)
  local config_mod = require("config")
  local cfg = config_mod.load()
  if cfg.hooks and cfg.hooks.yolo_mode then
    return true, nil
  end

  local perms  = require("agent.hooks.permissions")
  local status = perms.get(tool_name)

  if status == "always" then
    return true, nil

  elseif status == "blocked" then
    return false, "Ferramenta '" .. tool_name
      .. "' está bloqueada nas configurações de Hooks."

  else  -- "ask" — padrão para tools ainda não configuradas
    -- exec: sistema de padrões hierárquico (estilo Kilo Code)
    if tool_name == "exec" then
      local bp      = require("agent.hooks.bash_patterns")
      local matched, failed_sub = bp.matches(tool_arg)
      if matched then return true, nil end
      local allowed = bp.ask_user(tool_arg, failed_sub)
      return allowed, allowed and nil or "Bloqueado pelo usuário."
    end
    -- Outras tools: prompt simples de permissão
    local allowed = perms.ask_user(tool_name, tool_arg)
    return allowed, allowed and nil or "Bloqueado pelo usuário."
  end
end

-- ── Executor de scripts do usuário ────────────────────────────────────────
-- Roda todos os .lua e .sh em ~/.TermAI/hooks/<Evento>/
-- Falhas em scripts de usuário são reportadas mas não interrompem o agente.
function M._run_user_scripts(event, ...)
  local event_dir = HOOKS_DIR .. "/" .. event
  local h = io.popen('ls "' .. event_dir .. '" 2>/dev/null')
  if not h then return end
  local files = h:read("*a") or ""
  h:close()
  if files:match("^%s*$") then return end

  for fname in files:gmatch("[^\n]+") do
    if fname ~= "" then
      local fpath = event_dir .. "/" .. fname
      if fname:match("%.lua$") then
        local ok, err = pcall(dofile, fpath)
        if not ok then
          io.write("\27[38;5;203m⚠️  Hook Lua falhou ["
            .. event .. "/" .. fname .. "]: "
            .. tostring(err) .. "\27[0m\n")
          io.flush()
        end
      elseif fname:match("%.sh$") then
        os.execute('sh "' .. fpath .. '" >/dev/null 2>&1')
      end
    end
  end
end

return M
