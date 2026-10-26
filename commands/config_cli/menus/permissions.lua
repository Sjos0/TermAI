-- commands/config_cli/menus/permissions.lua
-- Menu de Permissoes de Ferramentas: always/ask/blocked.
local perms_mod = require("agent.hooks.permissions")
local tools_mod = require("tools")
local M = {}

-- Pede confirmação e aplica "Sempre" em todas (bloqueadas ficam como estão).
local function liberar_todas(ui, names)
  local bulk = require("commands.config.menus.permissions_bulk")
  local resposta = ui.rdl("Liberar TODAS como [Sempre]? (s/N)")
  if not bulk.is_confirmed(resposta) then
    io.write(ui.GR .. "\n  Cancelado.\n" .. ui.R)
    return
  end
  local liberadas, preservadas = bulk.allow_all(perms_mod, names)
  io.write(ui.G .. "\n  ✅ " .. liberadas .. " ferramenta(s) liberada(s) como [Sempre].\n" .. ui.R)
  if #preservadas > 0 then
    io.write(ui.YL .. "  Preservadas (bloqueadas): " .. table.concat(preservadas, ", ") .. "\n" .. ui.R)
  end
  ui.rdl("Enter para continuar")
end

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

    io.write("  "..ui.B.."a."..ui.R.."  Sempre para TODAS as ferramentas\n")
    io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")

    local ch = ui.rdl("Selecione uma ferramenta")
    if ui.cancel(ch) then break end
    local idx = tonumber(ch)
    if tostring(ch):lower() == "a" then
      liberar_todas(ui, names)
    elseif idx and names[idx] then
      local tname   = names[idx]
      local current = perms_mod.get(tname)
      ui.hdr("TermAI Config › Hooks › " .. tname)
      io.write("  Status atual: " .. (slabels[current] or current) .. "\n\n")
      io.write("  " .. ui.B .. "1." .. ui.R .. "  " .. ui.G .. "Sempre Permitida\n" .. ui.R)
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
