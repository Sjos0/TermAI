-- agent/hooks/bash_patterns/ui.lua — Prompt interativo de autorizações.
local suggest = require("agent.hooks.bash_patterns.suggest")
local rules = require("agent.hooks.bash_patterns.rules")

local M = {}

M.last_approval_type = nil
local session_denials = {}

local function get_wall_time()
  local f = io.open("/proc/uptime", "r")
  if not f then return os.time() end
  local val = f:read("*n")
  f:close()
  return val or os.time()
end

function M.ask_user(cmd, failed_sub)
  local y  = "\27[38;5;220m"
  local gr = "\27[38;5;242m"
  local w  = "\27[1;37m"
  local rs = "\27[0m"

  local display = cmd:gsub("[\1-\31]", "·")
  if #display > 150 then display = display:sub(1, 147) .. "..." end

  local target_for_pattern = failed_sub or cmd
  local pattern = suggest.get_suggested_pattern(target_for_pattern)

  io.write("\n")
  io.write(y .. "Comando Bash" .. rs .. "\n")
  io.write(gr .. "──────────────────────────────────────────────────" .. rs .. "\n")
  io.write("  " .. display .. "\n")
  if failed_sub and failed_sub ~= cmd then
    io.write(gr .. "  (Falha no trecho: " .. y .. failed_sub .. gr .. ")\n" .. rs)
  end
  io.write("\n")
  io.write(w .. "Deseja prosseguir?" .. rs .. "\n")
  io.write(y .. ") 1. Sim" .. rs .. "\n")
  io.write("  2. Sim, e não perguntar novamente para: " .. y .. pattern .. rs .. "\n")
  io.write("  3. Não\n\n")
  io.write(gr .. "[c] cancelar · [Enter] aprovar" .. rs .. "\n")
  io.write(y .. "Escolha (1/2/3): " .. rs)
  io.flush()

  local start_t = get_wall_time()
  local choice = (io.read("*l") or ""):match("^%s*(.-)%s*$")
  local elapsed = get_wall_time() - start_t

  if choice == "" and elapsed < 0.1 then
    choice = (io.read("*l") or ""):match("^%s*(.-)%s*$")
  end
  io.write("\n")

  if choice == "1" or choice == "" then
    M.last_approval_type = "APPROVED_ONCE"
    session_denials[pattern] = 0
    io.write(y .. "✅ Comando aprovado.\n" .. rs .. "\n")
    io.flush()
    return true
  elseif choice == "2" then
    M.last_approval_type = "PERMANENTLY_APPROVED"
    session_denials[pattern] = 0
    rules.add_pattern(pattern)
    io.write(y .. "✅ Regra adicionada: Comandos iniciando com '" .. pattern .. "' estão liberados.\n" .. rs .. "\n")
    io.flush()
    return true
  else
    M.last_approval_type = "CANCELLED"

    session_denials[pattern] = (session_denials[pattern] or 0) + 1
    if session_denials[pattern] >= 3 then
      io.write(y .. "⚠️  Você recusou o padrão '" .. pattern .. "' 3 vezes seguidas.\n")
      io.write("Deseja BLOQUEAR permanentemente a ferramenta de comandos? (s/N): " .. rs)
      io.flush()
      local block_ans = (io.read("*l") or ""):lower():match("^%s*(.-)%s*$")
      if block_ans == "s" or block_ans == "sim" then
        local perms = require("agent.hooks.permissions")
        perms.set("exec", "blocked")
        io.write(y .. "🚫 Ferramenta 'exec' configurada como BLOQUEADA permanentemente.\n\n" .. rs)
      end
      session_denials[pattern] = 0
    end

    io.write("\27[38;5;203m🚫 Cancelado.\n" .. rs .. "\n")
    io.flush()
    return false
  end
end

return M
