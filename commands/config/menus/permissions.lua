-- permissions.lua — Menu Permissões de Ferramentas
local ui = require("commands.models.ui")
local c  = ui.c
local SEP = string.rep("─", 45)
local M = {}

local function cls() io.write("\27[2J\27[H"); io.flush() end

function M.run(ctx)
  local perms_mod = require("agent.hooks.permissions")
  local tools_mod = require("tools")
  while true do
    cls()
    local names = {}
    for name in pairs(tools_mod.registry) do names[#names + 1] = name end
    table.sort(names)
    local slabels = {
      always  = c.green  .. "[Sempre]"    .. c.reset,
      ask     = c.yellow .. "[Perguntar]" .. c.reset,
      blocked = c.red    .. "[Bloqueada]" .. c.reset,
    }
    io.write("\n"..c.bold..c.cyan.."  Configurações › Hooks › Permissões"..c.reset.."\n")
    io.write(c.gray.."  "..SEP..c.reset.."\n\n")
    for i, name in ipairs(names) do
      local st = perms_mod.get(name)
      io.write(string.format("  %s%d.%s  %-28s %s\n",
        c.white, i, c.reset, name, slabels[st] or st))
    end
    io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")
    local ch = ui.prompt_read("Selecione uma ferramenta")
    if ui.is_cancel(ch) then break end
    local idx = tonumber(ch)
    if idx and names[idx] then
      local tname   = names[idx]
      local current = perms_mod.get(tname)
      io.write("\n  Ferramenta : "..c.bold..tname..c.reset.."\n")
      io.write("  Status atual: "..(slabels[current] or current).."\n\n")
      io.write("  "..c.white.."1."..c.reset.."  "..c.green .."Sempre Permitida"..c.reset.."\n")
      io.write("  "..c.white.."2."..c.reset.."  "..c.yellow.."Perguntar (padrão)"..c.reset.."\n")
      io.write("  "..c.white.."3."..c.reset.."  "..c.red   .."Bloqueada"..c.reset.."\n")
      io.write("  "..c.white.."0."..c.reset.."  Cancelar\n\n")
      local sch = ui.prompt_read("Novo status")
      local smap = {["1"]="always", ["2"]="ask", ["3"]="blocked"}
      if smap[sch] then
        perms_mod.set(tname, smap[sch])
        io.write(c.green.."\n  ✅ "..tname.." → "..smap[sch].."\n"..c.reset)
      else
        io.write(c.gray.."\n  Cancelado.\n"..c.reset)
      end
      ui.pause()
    end
  end
end

return M
