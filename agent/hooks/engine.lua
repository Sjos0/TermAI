-- agent/hooks/engine.lua — Motor central de eventos do sistema de Hooks.
-- Gerencia: PreToolUse, PostToolUse, OnAgentStop, OnMemoryFlush.
-- Suporta scripts do usuário (.lua e .sh) em ~/.TermAI/hooks/<Evento>/

local M = {}

local HOME      = os.getenv("HOME") or "/data/data/com.termux/files/home"
local HOOKS_DIR = HOME .. "/.TermAI/hooks"

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

function M._pre_tool_use(tool_name, tool_arg)
  local config_mod = require("config")
  local cfg = config_mod.load()

  local perms = require("tools.exec.permissions")
  if (cfg.hooks and cfg.hooks.yolo_mode) or perms.get_mode() == "bypass" then
    return true, nil
  end

  local warnings = {}
  local is_safe = true
  if tool_name == "Exec" then
    local security = require("tools.exec.security")
    local analysis = security.analyze(tool_arg)
    warnings = analysis.warnings
    is_safe = analysis.safe

    if not is_safe and analysis.severity == "high" then
      for _, w in ipairs(warnings) do
        if w.type == "traversal" then
          return false, "Bloqueio de segurança (Path Traversal): " .. w.message
        end
      end
    end
  end

  local check = perms.check(tool_name, tool_arg)
  if check.allowed then
    return true, nil
  end

  if check.reason == "blocked" or check.reason == "deny" then
    return false, "Ferramenta '" .. tool_name .. "' ou comando está bloqueado por regra de segurança."
  end

  local ui = require("tools.exec.permissions_ui")
  local choice, suggested_pattern = ui.show_dialog(tool_name, tool_arg, check.failed_sub, warnings, check.unknown_cmd)

  if choice == "once" then
    return true, nil
  elseif choice == "always" then
    if tool_name == "Exec" and suggested_pattern ~= "" then
      perms.add_rule(suggested_pattern, "allow", true)
    else
      perms.set_session_status(tool_name, "always")
      local compat_perms = require("agent.hooks.permissions")
      compat_perms.set(tool_name, "always")
    end
    return true, nil
  elseif choice == "block" then
    if tool_name == "Exec" and suggested_pattern ~= "" then
      perms.add_rule(suggested_pattern, "deny", true)
    else
      perms.set_session_status(tool_name, "blocked")
      local compat_perms = require("agent.hooks.permissions")
      compat_perms.set(tool_name, "blocked")
    end
    return false, "Bloqueado pelo usuário."
  else
    local target = (tool_name == "Exec" and suggested_pattern ~= "") and suggested_pattern or tool_name
    local threshold_reached = perms.increment_denial(target)
    if threshold_reached then
      io.write("\n\27[38;5;220m⚠️  Você recusou '" .. target .. "' consecutivamente.\n")
      io.write("Deseja BLOQUEAR permanentemente para evitar novas perguntas? (s/N): \27[0m")
      io.flush()
      local block_ans = (io.read("*l") or ""):lower():match("^%s*(.-)%s*$")
      if block_ans == "s" or block_ans == "sim" then
        if tool_name == "Exec" and suggested_pattern ~= "" then
          perms.add_rule(suggested_pattern, "deny", true)
        else
          perms.set_session_status(tool_name, "blocked")
          local compat_perms = require("agent.hooks.permissions")
          compat_perms.set(tool_name, "blocked")
        end
        io.write("\27[38;5;203m🚫 Bloqueado permanentemente.\n\n\27[0m")
        io.flush()
      end
    end
    local msg = string.format(
      "Solicitação '%s' negada pelo usuário. Devolva o input ao usuário e faça perguntas complementares para entender o que ele realmente quer antes de tentar novamente.",
      tostring(target)
    )
    return false, msg
  end
end

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
