-- commands/config_cli/menus/bash_patterns.lua
-- Menu de Padroes Bash: adicionar/remover comandos sempre permitidos (Sem Vazamento do Item 8 + Opção Limpar Tudo).

local bp_mod = require("agent.hooks.bash_patterns")
local M = {}

function M.run(config_mod, ui)
  while true do
    local patterns = bp_mod.list()
    ui.hdr("TermAI Config › Hooks › Padrões Bash")
    io.write(ui.DM.."  Bash commands que executam sem pedir permissão.\n\n"..ui.R)

    if #patterns == 0 then
      io.write(ui.GR.."  (nenhum padrão salvo)\n\n"..ui.R)
    else
      for i, p in ipairs(patterns) do
        io.write(string.format("  %s%d.%s  %s\"%s\"%s\n", ui.B, i, ui.R, ui.G, p, ui.R))
      end
      io.write("\n")
    end

    io.write(ui.GR.."  ── Opções "..ui.SEP2..ui.R.."\n")
    io.write("  "..ui.B.."A."..ui.R.."  Adicionar padrão\n")
    if #patterns > 0 then
      io.write("  "..ui.B.."R."..ui.R.."  Remover (número do padrão)\n")
      io.write("  "..ui.B.."C."..ui.R.."  Limpar todos os padrões (Reset)\n")
    end
    io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")

    local ch = ui.rdl("Escolha")
    if ui.cancel(ch) then break end

    if ch:lower() == "a" then
      local s = ui.rdl("Padrão (ex: luac -p, git, date +)")
      if s and s ~= "" then
        bp_mod.add_pattern(s)
        io.write(ui.G.."\n  ✅ Adicionado: \""..s.."\"\n"..ui.R)
      else io.write(ui.GR.."\n  Cancelado.\n"..ui.R) end
      ui.pause()
    elseif ch:lower() == "c" and #patterns > 0 then
      local confirm = ui.rdl("Deseja LIMPAR TODOS os padrões? (s/n)")
      if confirm:lower() == "s" then
        bp_mod.reset()
        io.write(ui.G.."\n  ✅ Todos os padrões foram limpos!\n"..ui.R)
      else
        io.write(ui.GR.."\n  Cancelado.\n"..ui.R)
      end
      ui.pause()
    else
      local idx = tonumber(ch)
      if idx and patterns[idx] then
        bp_mod.remove_pattern(patterns[idx])
        io.write(ui.G.."\n  ✅ Removido: \""..patterns[idx].."\"\n"..ui.R)
      else io.write(ui.RE.."\n  ❌ Opção inválida.\n"..ui.R) end
      ui.pause()
    end
  end
end

return M
