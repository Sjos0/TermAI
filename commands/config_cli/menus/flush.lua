-- commands/config_cli/menus/flush.lua
-- Menu de Memory Flush: ativar/desativar, alterar intervalo de tokens.
local M = {}

function M.run(config_mod, ui)
  while true do
    local cfg     = ui.get_cfg()
    local comp    = cfg.agents.defaults.compaction or {}
    local enabled = comp.flush_enabled ~= false
    local limit   = comp.flush_tokens or 40000

    ui.hdr("TermAI Config › Memory Flush")
    io.write(ui.GR.."  ── Status "..ui.SEP2..ui.R.."\n")
    ui.row("Flush:", enabled and (ui.G.."✅ Ativo"..ui.R) or (ui.RE.." ❌ Desativado"..ui.R))
    ui.row("Intervalo:", ui.fmt_k(limit).." tokens")
    io.write("\n"..ui.GR.."  ── Opções "..ui.SEP2..ui.R.."\n")
    io.write("  "..ui.B.."1."..ui.R.."  "..(enabled and (ui.RE.."Desativar"..ui.R) or (ui.G.."Ativar"..ui.R)).." Flush\n")
    io.write("  "..ui.B.."2."..ui.R.."  Alterar intervalo  "..ui.DM.."(mínimo: 5.000 tokens)"..ui.R.."\n")

    io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")

    local ch = ui.rdl("Escolha")
    if ui.cancel(ch) then break end

    if ch == "1" then
      local new = not enabled
      config_mod.set("agents.defaults.compaction.flush_enabled", new)
      io.write(new and (ui.G.."\n  ✅ Flush ativado.\n"..ui.R) or (ui.RE.."\n  ❌ Flush desativado.\n"..ui.R))
      ui.pause()

    elseif ch == "2" then
      local s = ui.rdl("Intervalo em tokens (ex: 40000)")
      local v = tonumber(s and s:gsub("[^%d]",""))
      if v and v >= 5000 then
        config_mod.set("agents.defaults.compaction.flush_tokens", v)
        io.write(ui.G.."\n  ✅ Intervalo: "..ui.fmt_k(v).." tokens\n"..ui.R)
      else io.write(ui.RE.."\n  ❌ Inválido (mínimo: 5000).\n"..ui.R) end
      ui.pause()
    end
  end
end

return M
