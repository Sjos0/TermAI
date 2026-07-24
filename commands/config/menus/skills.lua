-- skills.lua — Menu Skills
local ui = require("commands.models.ui")
local c  = ui.c
local SEP  = string.rep("─", 45)
local SEP2 = string.rep("─", 30)
local M = {}

local function cls() io.write("\27[2J\27[H"); io.flush() end

function M.run(ctx)
  local installer  = require("tools.skills.installer")
  local agent_name = "main"
  while true do
    cls()
    local global_skills = installer.list_global_skills()
    local agent_skills  = installer.list_agent_skills(agent_name)
    io.write("\n"..c.bold..c.cyan.."  Configuracoes > Skills"..c.reset.."\n")
    io.write(c.gray.."  "..SEP..c.reset.."\n\n")
    io.write(c.gray.."  ── Skills Globais "..SEP2..c.reset.."\n")
    if #global_skills == 0 then
      io.write(c.gray.."  (nenhuma skill global encontrada)\n"..c.reset)
    else
      for i, s in ipairs(global_skills) do
        io.write(string.format("  %s%d.%s  %-20s\n", c.white, i, c.reset, s.name))
      end
    end
    io.write("\n"..c.gray.."  ── Skills do Agente '"..agent_name.."' "..SEP2..c.reset.."\n")
    if #agent_skills == 0 then
      io.write(c.gray.."  (nenhuma instalada)\n"..c.reset)
    else
      for i, s in ipairs(agent_skills) do
        io.write(string.format("  %s%d.%s  %s\n", c.white, i, c.reset, s.name))
      end
    end
    io.write("\n"..c.gray.."  ── Opcoes "..SEP2..c.reset.."\n")
    io.write("  "..c.white.."1."..c.reset.."  Instalar skills globais no agente\n")
    io.write("  "..c.white.."2."..c.reset.."  Remover skills do agente\n")
    io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")
    local ch = ui.prompt_read("Escolha")
    if ui.is_cancel(ch) then break end
    if ch == "1" then
      if #global_skills == 0 then
        io.write(c.gray.."\n  Nenhuma skill global disponivel.\n"..c.reset)
        ui.pause()
      else
        io.write("\n")
        for i, s in ipairs(global_skills) do
          io.write(string.format("    %s%d.%s  %s\n", c.white, i, c.reset, s.name))
        end
        io.write("\n")
        local input = ui.prompt_read("Selecione para instalar (ex: 1,3)")
        if input and input ~= "" then
          local selected = {}
          for num in input:gmatch("%d+") do
            local idx = tonumber(num)
            if idx and global_skills[idx] then selected[#selected+1] = global_skills[idx].name end
          end
          if #selected > 0 then
            local report = installer.install_to_agent(selected, agent_name)
            io.write(c.green.."\n  "..report:gsub("\n", "\n  ").."\n"..c.reset)
          else io.write(c.gray.."\n  Nenhuma selecionada.\n"..c.reset) end
          ui.pause()
        end
      end
    elseif ch == "2" then
      if #agent_skills == 0 then
        io.write(c.gray.."\n  Nenhuma skill instalada.\n"..c.reset)
        ui.pause()
      else
        io.write("\n")
        for i, s in ipairs(agent_skills) do
          io.write(string.format("    %s%d.%s  %s\n", c.white, i, c.reset, s.name))
        end
        io.write("\n")
        local input = ui.prompt_read("Selecione para remover (ex: 1,2)")
        if input and input ~= "" then
          local selected = {}
          for num in input:gmatch("%d+") do
            local idx = tonumber(num)
            if idx and agent_skills[idx] then selected[#selected+1] = agent_skills[idx].name end
          end
          if #selected > 0 then
            local report = installer.uninstall_from_agent(selected, agent_name)
            io.write(c.green.."\n  "..report:gsub("\n", "\n  ").."\n"..c.reset)
          else io.write(c.gray.."\n  Nenhuma selecionada.\n"..c.reset) end
          ui.pause()
        end
      end
    end
  end
end

return M
