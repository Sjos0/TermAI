-- tools/exec/permissions_ui.lua — Interface TUI de diálogo para permissões
-- v5: diálogo modal em alternate screen (ESC[?1049h / ESC[?1049l]).
--     Tela principal intacta; sem contagem de linhas, sem ESC[1A/2K.
--     Cleanup garantido via xpcall mesmo em erro.
local suggest          = require("agent.hooks.bash_patterns.suggest")
local approval_backend = require("agent.hooks.approval_backend")

local M = {}

local function get_wall_time()
  local f = io.open("/proc/uptime", "r")
  if not f then return os.time() end
  local val = f:read("*n")
  f:close()
  return val or os.time()
end

-- ── Alternate screen (modal) ───────────────────────────────────────────────
-- DECSET 1049: salva cursor + entra na tela alternativa.
-- DECRST 1049: restaura tela principal + cursor.
-- O terminal cuida de scroll/wrap — não precisamos simular viewport.

local function enter_modal_screen()
  io.write("\27[?1049h")  -- alternate screen buffer
  io.write("\27[2J\27[H") -- clear + cursor home
  io.flush()
end

local function leave_modal_screen()
  io.write("\27[0m")      -- reset attributes
  io.write("\27[?1049l")  -- back to main screen
  io.flush()
end

-- Expostos só para testes unitários do lifecycle
M._enter_modal_screen = enter_modal_screen
M._leave_modal_screen = leave_modal_screen

local function display_text(s)
  s = tostring(s or "")
  s = s:gsub("[\r\n]+", "·"):gsub("[\1-\31]", "·")
  if #s > 120 then s = s:sub(1, 117) .. "..." end
  return s
end

local function compute_suggested_pattern(tool_name, command, failed_sub)
  if tool_name ~= "Exec" then return "" end
  local target = failed_sub or command
  local suggested_pattern = suggest.get_suggested_pattern(target)
  if suggested_pattern == ""
     or suggested_pattern:match("^%s*%*?%s*$")
     or suggested_pattern:match("^\\%s*%*")
     or not suggested_pattern:match("%w") then
    return ""
  end
  return suggested_pattern
end

-- Roda o diálogo DENTRO da alternate screen. Retorna decision, pattern, label_parts.
-- Nunca imprime o status final aqui — isso fica na tela principal após leave.
local function run_dialog(tool_name, command, failed_sub, warnings, unknown_cmd)
  local y  = "\27[38;5;220m"
  local gr = "\27[38;5;242m"
  local r  = "\27[38;5;203m"
  local g  = "\27[38;5;120m"
  local w  = "\27[1;37m"
  local rs = "\27[0m"

  local display_cmd = display_text(command)
  local display_sub = failed_sub and display_text(failed_sub) or nil
  local suggested_pattern = compute_suggested_pattern(tool_name, command, failed_sub)

  local function out(str)
    io.write(str)
  end

  out("\n")
  out(r .. "┌──────────────────────────────────────────────────┐" .. rs .. "\n")
  out(r .. "│" .. w .. "  🔒 SOLICITAÇÃO DE PERMISSÃO                      " .. r .. "│" .. rs .. "\n")
  out(r .. "└──────────────────────────────────────────────────┘" .. rs .. "\n")
  out(w .. "  Ferramenta: " .. y .. tool_name .. rs .. "\n")
  out(w .. "  Comando:    " .. rs .. display_cmd .. "\n")

  if display_sub and display_sub ~= display_cmd then
    out(gr .. "  (Subcomando pendente: " .. y .. display_sub .. gr .. ")" .. rs .. "\n")
  end

  if unknown_cmd then
    out(gr .. "  ⚠️  Este trecho não corresponde a um comando conhecido no PATH — "
         .. "pode ser texto do agente, não uma ação real." .. rs .. "\n")
  end

  if warnings and #warnings > 0 then
    out("\n" .. r .. "  ⚠️  AVISOS DE SEGURANÇA DETECTADOS:" .. rs .. "\n")
    for _, warn in ipairs(warnings) do
      out(r .. "  • " .. warn.message .. rs .. "\n")
    end
  end

  out("\n" .. w .. "  Escolha como prosseguir:" .. rs .. "\n")
  out(y .. "  [1] Permitir uma vez" .. rs .. "\n")

  if tool_name == "Exec" and suggested_pattern ~= "" then
    out(y .. "  [2] Permitir sempre para o padrão: " .. g .. suggested_pattern .. rs .. "\n")
  else
    out(y .. "  [2] Permitir sempre para esta ferramenta" .. rs .. "\n")
  end

  out(y .. "  [3] Negar" .. rs .. "\n")
  out(y .. "  [4] Bloquear permanentemente" .. rs .. "\n")
  out(gr .. "  [c] Cancelar" .. rs .. "\n\n")
  out(gr .. "  [Ctrl+C] cancelar · [Enter] aprovar uma vez" .. rs .. "\n")

  while true do
    out(y .. "  Escolha (1/2/3/4/c): " .. rs)
    io.flush()

    local start_t = get_wall_time()
    local choice = (io.read("*l") or "c"):match("^%s*(.-)%s*$")
    local elapsed = get_wall_time() - start_t

    if choice == "" and elapsed < 0.1 then
      choice = (io.read("*l") or "c"):match("^%s*(.-)%s*$")
    end

    choice = choice:lower()

    if choice == "1" or choice == "" then
      return "once", suggested_pattern, g, "✅", "Permitido uma vez"
    elseif choice == "2" then
      return "always", suggested_pattern, g, "✅", "Permitido sempre"
    elseif choice == "3" then
      return "deny", suggested_pattern, r, "🚫", "Negado"
    elseif choice == "4" then
      return "block", suggested_pattern, r, "🚫", "Bloqueado permanentemente"
    elseif choice == "c" or choice == "cancelar" then
      return "cancel", suggested_pattern, r, "🚫", "Cancelado"
    else
      out(r .. "  Entrada inválida. Digite 1, 2, 3, 4 ou c." .. rs .. "\n")
    end
  end
end

function M.show_dialog(tool_name, command, failed_sub, warnings, unknown_cmd)
  local backend = approval_backend.tool_backend()
  if backend then return backend(tool_name, command, failed_sub, warnings) end

  -- 1. Entra no modal
  enter_modal_screen()

  -- 2. Roda o diálogo com garantia de leave mesmo em erro
  local ok, a, b, c, d, e = xpcall(function()
    return run_dialog(tool_name, command, failed_sub, warnings, unknown_cmd)
  end, debug.traceback)

  -- 3. SEMPRE sai do modal (tela principal restaurada pelo terminal)
  leave_modal_screen()

  if not ok then
    -- a = traceback; propaga sem deixar o usuário preso na alternate screen
    error(a, 0)
  end

  -- 4. Status só na tela principal
  local decision, pattern, color, icon, label = a, b, c, d, e
  local rs = "\27[0m"
  io.write(color .. "  " .. icon .. " " .. label .. rs .. "\n\n")
  io.flush()

  return decision, pattern
end

return M
