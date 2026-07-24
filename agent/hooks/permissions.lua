-- agent/hooks/permissions.lua — Gerenciador de permissões por ferramenta (Estilo Claude Code).
-- Status possíveis: "always" | "ask" | "blocked"
-- Padrão para tools desconhecidas: "ask"

local M = {}
local config_mod = require("config")

M.last_approval_type = nil

-- Rastreamento de rejeições da sessão (Claude Code Denial Tracking)
local session_denials = {}

-- ── Leitura ────────────────────────────────────────────────────────────────
function M.get(tool_name)
  local cfg   = config_mod.load()
  local perms = cfg.hooks and cfg.hooks.permissions
  if not perms then return "ask" end
  return perms[tool_name] or "ask"
end

-- ── Escrita ────────────────────────────────────────────────────────────────
function M.set(tool_name, status)
  local cfg = config_mod.load()
  if not cfg.hooks             then cfg.hooks             = {} end
  if not cfg.hooks.permissions then cfg.hooks.permissions = {} end
  cfg.hooks.permissions[tool_name] = status
  config_mod.save(cfg)
end

-- ── Prompt interativo (Claude Code Style Traduzido) ─────────────────────────
function M.ask_user(tool_name, tool_arg)
  local y  = "\27[38;5;220m" -- Yellow/Gold
  local gr = "\27[38;5;242m" -- Dark Gray para divisores e rodapé
  local w  = "\27[1;37m"     -- Bold White
  local rs = "\27[0m"        -- Reset

  local display = tostring(tool_arg or "")
  if #display > 100 then display = display:sub(1, 97) .. "..." end
  display = display:gsub("[\1-\31]", "·")

  io.write("\n")
  io.write(y .. "Chamada de ferramenta (" .. tool_name .. ")" .. rs .. "\n")
  io.write(gr .. "──────────────────────────────────────────────────" .. rs .. "\n")
  io.write("  " .. display .. "\n\n")
  io.write(w .. "Deseja prosseguir?" .. rs .. "\n")
  io.write(y .. ") 1. Sim" .. rs .. "\n")
  io.write("  2. Sim, e não perguntar novamente para esta ferramenta\n")
  io.write("  3. Não\n\n")
  io.write(gr .. "[c] cancelar · [Enter] aprovar" .. rs .. "\n")
  io.write(y .. "Escolha (1/2/3): " .. rs)
  io.flush()

  local choice = (io.read("*l") or ""):match("^%s*(.-)%s*$")
  io.write("\n")

  if choice == "1" or choice == "" then
    M.last_approval_type = "APPROVED_ONCE"
    session_denials[tool_name] = 0
    io.write(y .. "✅ Executando uma vez.\n" .. rs .. "\n")
    io.flush()
    return true
  elseif choice == "2" then
    M.last_approval_type = "PERMANENTLY_APPROVED"
    session_denials[tool_name] = 0
    M.set(tool_name, "always")
    io.write(y .. "✅ Ferramenta '" .. tool_name .. "' autorizada para sempre.\n" .. rs .. "\n")
    io.flush()
    return true
  else
    M.last_approval_type = "CANCELLED"

    -- Denial Tracking: incrementa recusas da ferramenta nesta sessão
    session_denials[tool_name] = (session_denials[tool_name] or 0) + 1
    if session_denials[tool_name] >= 3 then
      io.write(y .. "⚠️  Você recusou a ferramenta '" .. tool_name .. "' 3 vezes seguidas.\n")
      io.write("Deseja BLOQUEAR permanentemente esta ferramenta para evitar novas perguntas? (s/N): " .. rs)
      io.flush()
      local block_ans = (io.read("*l") or ""):lower():match("^%s*(.-)%s*$")
      if block_ans == "s" or block_ans == "sim" then
        M.set(tool_name, "blocked")
        io.write(y .. "🚫 Ferramenta '" .. tool_name .. "' configurada como BLOQUEADA permanentemente.\n\n" .. rs)
      end
      session_denials[tool_name] = 0
    end

    io.write("\27[38;5;203m🚫 Cancelado.\n" .. rs .. "\n")
    io.flush()
    return false
  end
end

return M
