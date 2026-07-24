-- commands/config_cli/menus/permissions.lua
-- Menu de Permissoes de Ferramentas: always/ask/blocked.
local perms_mod = require("agent.hooks.permissions")
local tools_mod = require("tools")
local M = {}

function M.run(config_mod, ui)
  while true do
    local names = {}
    for name in pairs(tools_mod.registry) do names[#names + 1] = name end
    table.sort(names)

    local slabels = {
      always  = ui.G  .. "[Sempre]"    .. ui.R,
      ask     = ui.YL .. "[Perguntar]" .. ui.R,
      blocked = ui.RE .. "[Bloqueada]" .. ui.R,
    }

    ui.hdr("TermAI Config › Hooks › Permissões")
    for i, name in ipairs(names) do
      local st = perms_mod.get(name)
      io.write(string.format("  %s%d.%s  %-28s %s\n",
        ui.B, i, ui.R, name, slabels[st] or st))
    end

    io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")

    local ch = ui.rdl("Selecione uma ferramenta")
    if ui.cancel(ch) then break end
    local idx = tonumber(ch)
    if idx and names[idx] then
      local tname   = names[idx]
      local current = perms_mod.get(tname)
      ui.hdr("TermAI Config › Hooks › " .. tname)
      io.write("  Status atual: " .. (slabels[current] or current) .. "\n\n")
      io.write("  "..ui.B.."1."..ui.R.."  "..ui.G .."Sempre Permitida\n"..ui.R)
      io.write("  "..ui.B.."2."..ui.R.."  "..ui.YL.."Perguntar (padrão)\n"..ui.R)
      io.write("  "..ui.B.."3."..ui.R.."  "..ui.RE.."Bloqueada\n"..ui.R)
      io.write("  "..ui.B.."0."..ui.R.."  Cancelar\n\n")
      local sch = ui.rdl("Novo status")
      local smap = {["1"]="always", ["2"]="ask", ["3"]="blocked"}
      if smap[sch] then
        perms_mod.set(tname, smap[sch])
        io.write(ui.G.."\n  ✅ "..tname.." → "..smap[sch].."\n"..ui.R)
      else io.write(ui.GR.."\n  Cancelado.\n"..ui.R) end
      ui.pause()
    end
  end
end

return M
