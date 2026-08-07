-- tools/exec/permissions_ui.lua — Interface TUI de diálogo para permissões
-- v3: colapso por cursor save/restore (não depende de contar \n — tolera wrap)
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

function M.show_dialog(tool_name, command, failed_sub, warnings, unknown_cmd)
  local backend = approval_backend.tool_backend()
  if backend then return backend(tool_name, command, failed_sub, warnings) end

  local y  = "\27[38;5;220m"
  local gr = "\27[38;5;242m"
  local r  = "\27[38;5;203m"
  local g  = "\27[38;5;120m"
  local w  = "\27[1;37m"
  local rs = "\27[0m"

  local function display_text(s)
    s = tostring(s or "")
    s = s:gsub("[\r\n]+", "·"):gsub("[\1-\31]", "·")
    if #s > 120 then s = s:sub(1, 117) .. "..." end
    return s
  end

  local display_cmd = display_text(command)
  local display_sub = failed_sub and display_text(failed_sub) or nil

  local suggested_pattern = ""
  if tool_name == "Exec" then
    local target = failed_sub or command
    suggested_pattern = suggest.get_suggested_pattern(target)
    if suggested_pattern == ""
       or suggested_pattern:match("^%s*%*?%s*$")
       or suggested_pattern:match("^\\%s*%*")
       or not suggested_pattern:match("%w") then
      suggested_pattern = ""
    end
  end

  -- Marca a posição ANTES de qualquer linha do diálogo.
  -- No resolve: volta aqui e apaga tudo abaixo — independente de wrap visual.
  io.write("\27[s")
  io.flush()

  local function wl(str)
    io.write(str)
  end

  wl("\n")
  wl(r .. "┌──────────────────────────────────────────────────┐" .. rs .. "\n")
  wl(r .. "│" .. w .. "  🔒 SOLICITAÇÃO DE PERMISSÃO                      " .. r .. "│" .. rs .. "\n")
  wl(r .. "└──────────────────────────────────────────────────┘" .. rs .. "\n")
  wl(w .. "  Ferramenta: " .. y .. tool_name .. rs .. "\n")
  wl(w .. "  Comando:    " .. rs .. display_cmd .. "\n")

  if display_sub and display_sub ~= display_cmd then
    wl(gr .. "  (Subcomando pendente: " .. y .. display_sub .. gr .. ")" .. rs .. "\n")
  end

  if unknown_cmd then
    wl(gr .. "  ⚠️  Este trecho não corresponde a um comando conhecido no PATH — "
       .. "pode ser texto do agente, não uma ação real." .. rs .. "\n")
  end

  if warnings and #warnings > 0 then
    wl("\n" .. r .. "  ⚠️  AVISOS DE SEGURANÇA DETECTADOS:" .. rs .. "\n")
    for _, warn in ipairs(warnings) do
      wl(r .. "  • " .. warn.message .. rs .. "\n")
    end
  end

  wl("\n" .. w .. "  Escolha como prosseguir:" .. rs .. "\n")
  wl(y .. "  [1] Permitir uma vez" .. rs .. "\n")

  if tool_name == "Exec" and suggested_pattern ~= "" then
    wl(y .. "  [2] Permitir sempre para o padrão: " .. g .. suggested_pattern .. rs .. "\n")
  else
    wl(y .. "  [2] Permitir sempre para esta ferramenta" .. rs .. "\n")
  end

  wl(y .. "  [3] Negar" .. rs .. "\n")
  wl(y .. "  [4] Bloquear permanentemente" .. rs .. "\n")
  wl(gr .. "  [c] Cancelar" .. rs .. "\n\n")
  wl(gr .. "  [Ctrl+C] cancelar · [Enter] aprovar uma vez" .. rs .. "\n")

  local function collapse_and_resolve(color, icon, label)
    -- Volta ao ponto salvo e apaga tudo até o fim da tela
    io.write("\27[u\27[0J")
    io.write(color .. "  " .. icon .. " " .. label .. rs .. "\n")
    io.flush()
  end

  while true do
    io.write(y .. "  Escolha (1/2/3/4/c): " .. rs)
    io.flush()

    local start_t = get_wall_time()
    local choice = (io.read("*l") or "c"):match("^%s*(.-)%s*$")
    local elapsed = get_wall_time() - start_t

    if choice == "" and elapsed < 0.1 then
      choice = (io.read("*l") or "c"):match("^%s*(.-)%s*$")
    end

    choice = choice:lower()

    if choice == "1" or choice == "" then
      collapse_and_resolve(g, "✅", "Permitido uma vez")
      return "once", suggested_pattern
    elseif choice == "2" then
      collapse_and_resolve(g, "✅", "Permitido sempre")
      return "always", suggested_pattern
    elseif choice == "3" then
      collapse_and_resolve(r, "🚫", "Negado")
      return "deny", suggested_pattern
    elseif choice == "4" then
      collapse_and_resolve(r, "🚫", "Bloqueado permanentemente")
      return "block", suggested_pattern
    elseif choice == "c" or choice == "cancelar" then
      collapse_and_resolve(r, "🚫", "Cancelado")
      return "cancel", suggested_pattern
    else
      wl(r .. "  Entrada inválida. Digite 1, 2, 3, 4 ou c." .. rs .. "\n")
    end
  end
end

return M
