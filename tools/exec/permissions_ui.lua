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
function M.show_dialog(tool_name, command, failed_sub, warnings, unknown_cmd)
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

  -- Trunca e sanitiza qualquer texto exibido na caixa (comando ou subcomando),
  -- evitando que um fragmento gigante estoure a TUI (bug: overflow do "subcomando pendente")
  local function display_text(s)
    s = tostring(s or "")
    if #s > 150 then s = s:sub(1, 147) .. "..." end
    return s:gsub("[\1-\31]", "·")
  end

  local display_cmd = display_text(command)
  local display_sub = failed_sub and display_text(failed_sub) or nil

  local suggested_pattern = ""
  if tool_name == "Exec" then
    local target = failed_sub or command
    suggested_pattern = suggest.get_suggested_pattern(target)
  end

  -- Conta as linhas escritas para poder colapsar a caixa inteira depois da decisão
  -- (mesmo idioma de cursor-up + clear já usado em ui/stream.lua: "\27[1A\27[K")
  local lines_written = 0
  local function wl(str)
    io.write(str)
    local _, n = str:gsub("\n", "\n")
    lines_written = lines_written + n
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

  -- Exibe avisos de segurança se houver
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

  -- Colapsa a caixa inteira (lines_written linhas) e imprime 1 linha-resumo resolvida no lugar.
  -- Resolve o bug de "a solicitação nunca some da TUI ao vivo até reiniciar": em vez de deixar
  -- a caixa interativa presa no scrollback pra sempre, ela vira uma linha de status estática,
  -- consistente com o que o replay mostraria (nada — já que o evento não é persistido na sessão).
  local function collapse_and_resolve(color, icon, label)
    for _ = 1, lines_written do io.write("\27[1A\27[K") end
    io.write(color .. "  " .. icon .. " " .. label .. ": " .. rs .. display_cmd .. "\n\n")
    io.flush()
  end

  while true do
    io.write(y .. "  Escolha (1/2/3/4/c): " .. rs)
    io.flush()
    lines_written = lines_written + 1

    local start_t = get_wall_time()
    local choice = (io.read("*l") or "c"):match("^%s*(.-)%s*$")
    local elapsed = get_wall_time() - start_t

    -- Prevenção de falso auto-submit sob certas TTYs/popen
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
