-- commands/config_cli/menus/skills.lua
-- Menu de Skills: instalar/remover skills no agente.
local installer = require("tools.skills.installer")
local M = {}

function M.run(config_mod, ui)
  local agent_name = "main"
  while true do
    local global_skills = installer.list_global_skills()
    local agent_skills  = installer.list_agent_skills(agent_name)
    ui.hdr("TermAI Config > Skills")
    io.write(ui.GR.."  -- Skills Globais "..ui.SEP2..ui.R.."\n")
    if #global_skills == 0 then
      io.write(ui.GR.."  (nenhuma skill global encontrada)\n"..ui.R)
    else
      for i, s in ipairs(global_skills) do
        io.write(string.format("  %s%d.%s  %-20s\n", ui.B, i, ui.R, s.name))
      end
    end
    io.write("\n"..ui.GR.."  -- Skills do Agente '"..agent_name.."' "..ui.SEP2..ui.R.."\n")
    if #agent_skills == 0 then
      io.write(ui.GR.."  (nenhuma instalada)\n"..ui.R)
    else
      for i, s in ipairs(agent_skills) do
        io.write(string.format("  %s%d.%s  %s\n", ui.B, i, ui.R, s.name))
      end
    end
    io.write("\n"..ui.GR.."  -- Opcoes "..ui.SEP2..ui.R.."\n")
    io.write("  "..ui.B.."1."..ui.R.."  Instalar skills globais no agente\n")
    io.write("  "..ui.B.."2."..ui.R.."  Remover skills do agente\n")

    io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")
    local ch = ui.rdl("Escolha")
    if ui.cancel(ch) then break end

    if ch == "1" then
      if #global_skills == 0 then
        io.write(ui.GR.."\n  Nenhuma skill global disponivel.\n"..ui.R)
        ui.pause()
      else
        io.write("\n")
        for i, s in ipairs(global_skills) do
          io.write(string.format("    %s%d.%s  %s\n", ui.B, i, ui.R, s.name))
        end
        io.write("\n")
        local input = ui.rdl("Selecione para instalar (ex: 1,3)")
        if input and input ~= "" then
          local selected = {}
          for num in input:gmatch("%d+") do
            local idx = tonumber(num)
            if idx and global_skills[idx] then selected[#selected+1] = global_skills[idx].name end
          end
          if #selected > 0 then
            local report = installer.install_to_agent(selected, agent_name)
            io.write(ui.G.."\n  "..report:gsub("\n", "\n  ").."\n"..ui.R)
          else io.write(ui.GR.."\n  Nenhuma selecionada.\n"..ui.R) end
          ui.pause()
        end
      end

    elseif ch == "2" then
      if #agent_skills == 0 then
        io.write(ui.GR.."\n  Nenhuma skill instalada.\n"..ui.R)
        ui.pause()
      else
        io.write("\n")
        for i, s in ipairs(agent_skills) do
          io.write(string.format("    %s%d.%s  %s\n", ui.B, i, ui.R, s.name))
        end
        io.write("\n")
        local input = ui.rdl("Selecione para remover (ex: 1,2)")
        if input and input ~= "" then
          local selected = {}
          for num in input:gmatch("%d+") do
            local idx = tonumber(num)
            if idx and agent_skills[idx] then selected[#selected+1] = agent_skills[idx].name end
          end
          if #selected > 0 then
            local report = installer.uninstall_from_agent(selected, agent_name)
            io.write(ui.G.."\n  "..report:gsub("\n", "\n  ").."\n"..ui.R)
          else io.write(ui.GR.."\n  Nenhuma selecionada.\n"..ui.R) end
          ui.pause()
        end
      end
    end
  end
end

return M
