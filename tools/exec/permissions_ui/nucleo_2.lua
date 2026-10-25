-- tools/exec/permissions_ui/nucleo_2.lua — helpers internos: run_dialog.
return function(M)
  local P = require("tools.exec.permissions_ui.nucleo_1")(M)
  local get_wall_time, display_text, compute_suggested_pattern = P.get_wall_time, P.display_text, P.compute_suggested_pattern


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
  local N = {}
  for k, v in pairs(P) do N[k] = v end
  N.run_dialog = run_dialog
  return N
end
