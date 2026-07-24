-- commands/config_cli/menus/hooks.lua
-- Menu de Hooks & Automacao: max retries, max iter, permissoes, bash patterns.
local permissions_menu   = require("commands.config_cli.menus.permissions")
local bash_patterns_menu = require("commands.config_cli.menus.bash_patterns")
local M = {}

function M.run(config_mod, ui)
  while true do
    local cfg         = ui.get_cfg()
    local hooks_cfg   = cfg.agents.defaults.hooks or {}
    local max_retries = hooks_cfg.max_tool_retries or 3
    local raw_iter    = cfg.agents.defaults.maxIter or 20
    local iter_label  = (raw_iter == 0) and (ui.G.."Ilimitado"..ui.R) or tostring(raw_iter)

    ui.hdr("TermAI Config › Hooks & Automação")
    io.write(ui.GR.."  ── Escudo Anti-Burrice "..ui.SEP2..ui.R.."\n")
    ui.row("Max tentativas de erro:", tostring(max_retries).."  "..ui.DM.."(1 – 10)"..ui.R)
    io.write("\n"..ui.GR.."  ── Limites do Agente "..ui.SEP2..ui.R.."\n")
    ui.row("Max iterações de tools:", iter_label)
    io.write("\n"..ui.GR.."  ── Opções "..ui.SEP2..ui.R.."\n")
    io.write("  "..ui.B.."1."..ui.R.."  Alterar max tentativas de erro  "..ui.DM.."(padrão: 3)"..ui.R.."\n")
    io.write("  "..ui.B.."2."..ui.R.."  Alterar max iterações de tools  "..ui.DM.."(0 = ilimitado)"..ui.R.."\n")
    io.write("  "..ui.B.."3."..ui.R.."  Gerenciar permissões de ferramentas\n")
    io.write("  "..ui.B.."4."..ui.R.."  Padrões Bash  "..ui.DM.."(comandos sempre permitidos)"..ui.R.."\n")

    io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")

    local ch = ui.rdl("Escolha")
    if ui.cancel(ch) then break end

    if ch == "1" then
      local s = ui.rdl("Max tentativas de erro (1 – 10, padrão: 3)")
      local v = tonumber(s)
      if v and v >= 1 and v <= 10 then
        config_mod.set("agents.defaults.hooks.max_tool_retries", v)
        io.write(ui.G.."\n  ✅ Max tentativas de erro: "..v.."\n"..ui.R)
      else io.write(ui.RE.."\n  ❌ Inválido (1 – 10).\n"..ui.R) end
      ui.pause()

    elseif ch == "2" then
      io.write(ui.DM.."  0 = ilimitado  |  número positivo = limite fixo\n\n"..ui.R)
      local s = ui.rdl("Max iterações (0 = ilimitado, padrão: 20)")
      local v = tonumber(s)
      if v and v >= 0 then
        config_mod.set("agents.defaults.maxIter", v)
        local lbl = (v == 0) and "Ilimitado" or tostring(v)
        io.write(ui.G.."\n  ✅ Max iterações: "..lbl.."\n"..ui.R)
        if v == 0 then
          io.write(ui.YL.."  ⚠️  Sem limite: monitore o consumo de tokens.\n"..ui.R)
        end
      else io.write(ui.RE.."\n  ❌ Inválido.\n"..ui.R) end
      ui.pause()

    elseif ch == "3" then
      permissions_menu.run(config_mod, ui)
    elseif ch == "4" then
      bash_patterns_menu.run(config_mod, ui)
    end
  end
end

return M
