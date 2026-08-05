-- tools/exec/permissions_ui.lua — Interface TUI de diálogo para permissões
local suggest         = require("agent.hooks.bash_patterns.suggest")
local approval_backend = require("agent.hooks.approval_backend")

local M = {}

local function get_wall_time()
  local f = io.open("/proc/uptime", "r")
  if not f then return os.time() end
  local val = f:read("*n")
  f:close()
  return val or os.time()
end

-- Mostra o diálogo interativo e retorna a decisão ("once", "always", "deny", "block", "cancel")
function M.show_dialog(tool_name, command, failed_sub, warnings)
  -- Canais sem TTY (ex: channels/telegram) registram um backend alternativo.
  -- Sem backend registrado, o comportamento de terminal abaixo é inalterado.
  local backend = approval_backend.tool_backend()
  if backend then return backend(tool_name, command, failed_sub, warnings) end

  local y  = "\27[38;5;220m" -- Amarelo/Dourado
  local gr = "\27[38;5;242m" -- Cinza Escuro
  local r  = "\27[38;5;203m" -- Vermelho
  local g  = "\27[38;5;120m" -- Verde Claro
  local w  = "\27[1;37m"     -- Branco Negrito
  local rs = "\27[0m"        -- Reset

  local display_cmd = tostring(command or "")
  if #display_cmd > 150 then display_cmd = display_cmd:sub(1, 147) .. "..." end
  display_cmd = display_cmd:gsub("[\1-\31]", "·")

  local suggested_pattern = ""
  if tool_name == "Exec" then
    local target = failed_sub or command
    suggested_pattern = suggest.get_suggested_pattern(target)
  end

  io.write("\n")
  io.write(r .. "┌──────────────────────────────────────────────────┐" .. rs .. "\n")
  io.write(r .. "│" .. w .. "  🔒 SOLICITAÇÃO DE PERMISSÃO                      " .. r .. "│" .. rs .. "\n")
  io.write(r .. "└──────────────────────────────────────────────────┘" .. rs .. "\n")
  io.write(w .. "  Ferramenta: " .. y .. tool_name .. rs .. "\n")
  io.write(w .. "  Comando:    " .. rs .. display_cmd .. "\n")

  if failed_sub and failed_sub ~= command then
    io.write(gr .. "  (Subcomando pendente: " .. y .. failed_sub .. gr .. ")" .. rs .. "\n")
  end

  -- Exibe avisos de segurança se houver
  if warnings and #warnings > 0 then
    io.write("\n" .. r .. "  ⚠️  AVISOS DE SEGURANÇA DETECTADOS:" .. rs .. "\n")
    for _, warn in ipairs(warnings) do
      io.write(r .. "  • " .. warn.message .. rs .. "\n")
    end
  end

  io.write("\n" .. w .. "  Escolha como prosseguir:" .. rs .. "\n")
  io.write(y .. "  [1] Permitir uma vez" .. rs .. "\n")

  if tool_name == "Exec" and suggested_pattern ~= "" then
    io.write(y .. "  [2] Permitir sempre para o padrão: " .. g .. suggested_pattern .. rs .. "\n")
  else
    io.write(y .. "  [2] Permitir sempre para esta ferramenta" .. rs .. "\n")
  end

  io.write(y .. "  [3] Negar" .. rs .. "\n")
  io.write(y .. "  [4] Bloquear permanentemente" .. rs .. "\n")
  io.write(gr .. "  [c] Cancelar" .. rs .. "\n\n")
  io.write(gr .. "  [Ctrl+C] cancelar · [Enter] aprovar uma vez" .. rs .. "\n")

  while true do
    io.write(y .. "  Escolha (1/2/3/4/c): " .. rs)
    io.flush()

    local start_t = get_wall_time()
    local choice = (io.read("*l") or "c"):match("^%s*(.-)%s*$")
    local elapsed = get_wall_time() - start_t

    -- Prevenção de falso auto-submit sob certas TTYs/popen
    if choice == "" and elapsed < 0.1 then
      choice = (io.read("*l") or "c"):match("^%s*(.-)%s*$")
    end

    choice = choice:lower()

    if choice == "1" or choice == "" then
      io.write("\n" .. g .. "  ✅ Permitido uma vez." .. rs .. "\n\n")
      io.flush()
      return "once", suggested_pattern
    elseif choice == "2" then
      io.write("\n" .. g .. "  ✅ Permitido sempre." .. rs .. "\n\n")
      io.flush()
      return "always", suggested_pattern
    elseif choice == "3" then
      io.write("\n" .. r .. "  🚫 Negado." .. rs .. "\n\n")
      io.flush()
      return "deny", suggested_pattern
    elseif choice == "4" then
      io.write("\n" .. r .. "  🚫 Bloqueado permanentemente." .. rs .. "\n\n")
      io.flush()
      return "block", suggested_pattern
    elseif choice == "c" or choice == "cancelar" then
      io.write("\n" .. r .. "  🚫 Cancelado." .. rs .. "\n\n")
      io.flush()
      return "cancel", suggested_pattern
    else
      io.write(r .. "  Entrada inválida. Digite 1, 2, 3, 4 ou c." .. rs .. "\n")
    end
  end
end

return M
