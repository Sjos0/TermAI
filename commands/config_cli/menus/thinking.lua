-- commands/config_cli/menus/thinking.lua
-- Menu de Raciocinio Estimulado: ativar/desativar, alterar nivel.
local M = {}

function M.run(config_mod, ui)
  while true do
    local cfg     = ui.get_cfg()
    local tp      = cfg.agents.defaults.thinking_protocol or {}
    local enabled = tp.enabled == true
    local effort  = tp.effort or "medium"

    ui.hdr("TermAI Config › Raciocínio Estimulado")
    io.write(ui.DM..[[  Injeta protocolo de pensamento no System Prompt.
  Para modelos SEM reasoning: força tags <think>...</think>.
  Para modelos COM reasoning: reforça a profundidade do raciocínio.
  Reinicie a TUI após alterar para o prompt ser atualizado.
]]..ui.R.."\n")
    io.write(ui.GR.."  ── Status "..ui.SEP2..ui.R.."\n")
    ui.row("Protocolo:", enabled and (ui.G.."✅ Ativo"..ui.R) or (ui.RE.."❌ Desativado"..ui.R))
    ui.row("Nível:", effort)
    io.write("\n"..ui.GR.."  ── Opções "..ui.SEP2..ui.R.."\n")
    io.write("  "..ui.B.."1."..ui.R.."  "..(enabled and (ui.RE.."Desativar"..ui.R) or (ui.G.."Ativar"..ui.R)).." Protocolo\n")
    io.write("  "..ui.B.."2."..ui.R.."  Alterar nível  "..ui.DM.."(low / medium / high)"..ui.R.."\n")

    io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")

    local ch = ui.rdl("Escolha")
    if ui.cancel(ch) then break end

    if ch == "1" then
      local new = not enabled
      config_mod.set("agents.defaults.thinking_protocol.enabled", new)
      io.write(new and (ui.G.."\n  ✅ Ativado. Reinicie a TUI.\n"..ui.R)
                    or (ui.RE.."\n  ❌ Desativado. Reinicie a TUI.\n"..ui.R))
      ui.pause()

    elseif ch == "2" then
      io.write("  "..ui.B.."1."..ui.R.."  low     "..ui.DM.."(rápido, 2-4 linhas de raciocínio)"..ui.R.."\n")
      io.write("  "..ui.B.."2."..ui.R.."  medium  "..ui.DM.."(passo a passo, 1-2 parágrafos)"..ui.R.."\n")
      io.write("  "..ui.B.."3."..ui.R.."  high    "..ui.DM.."(exaustivo, máxima profundidade)"..ui.R.."\n\n")
      local lch = ui.rdl("Nível (1/2/3)")
      local lvls = {["1"]="low", ["2"]="medium", ["3"]="high"}
      if lvls[lch] then
        config_mod.set("agents.defaults.thinking_protocol.effort", lvls[lch])
        io.write(ui.G.."\n  ✅ Nível: "..lvls[lch]..". Reinicie a TUI.\n"..ui.R)
      else io.write(ui.RE.."\n  ❌ Inválido.\n"..ui.R) end
      ui.pause()
    end
  end
end

return M
