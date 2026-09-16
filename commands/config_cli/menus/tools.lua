-- commands/config_cli/menus/tools.lua
-- Menu CLI: desativar/reativar tools por agente ativo (Issue #32).
local tools_mod = require("tools")
local M = {}

local function resolve_agent_id(cfg)
  return (cfg.agents and cfg.agents.list and cfg.agents.list[1] and
          cfg.agents.list[1].id) or "main"
end

local function get_disabled_list(config_mod, agent_id)
  local agent = config_mod.get_agent(agent_id)
  if not agent then return {} end
  local list = agent.disabled_tools or {}
  local out = {}
  for _, n in ipairs(list) do
    if type(n) == "string" then out[#out + 1] = n end
  end
  return out
end

local function to_set(list)
  local s = {}
  for _, n in ipairs(list) do s[n] = true end
  return s
end

local function save_disabled(config_mod, agent_id, list)
  local cfg = config_mod.load()
  local agents = cfg.agents and cfg.agents.list or {}
  for i, agent in ipairs(agents) do
    if agent.id == agent_id then
      agents[i].disabled_tools = list
      break
    end
  end
  config_mod.set("agents.list", agents)
end

local function sorted_tool_names()
  local names = {}
  for name in pairs(tools_mod.registry) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

function M.run(config_mod, ui)
  while true do
    local cfg = config_mod.load()
    local agent_id = resolve_agent_id(cfg)
    local disabled = get_disabled_list(config_mod, agent_id)
    local dset = to_set(disabled)
    local names = sorted_tool_names()

    ui.hdr("TermAI Config › Tools (agente: " .. agent_id .. ")")
    io.write(ui.DM..[[  Desativar remove a tool do schema do modelo.
  Permissões (ask/block) são outra coisa — só valem para tools ativas.
]]..ui.R.."\n")

    io.write(ui.GR.."  ── Tools "..ui.SEP2..ui.R.."\n")
    for i, name in ipairs(names) do
      local data = tools_mod.registry[name]
      local desc = (data and data.desc) or ""
      if #desc > 36 then desc = desc:sub(1, 33) .. "..." end
      local status = dset[name]
        and (ui.RE.."❌ desativada"..ui.R)
        or  (ui.G.."✅ ativa"..ui.R)
      io.write(string.format("  %s%2d.%s  %-18s %s  %s%s%s\n",
        ui.B, i, ui.R, name, status, ui.DM, desc, ui.R))
    end

    io.write("\n"..ui.GR.."  ── Ações "..ui.SEP2..ui.R.."\n")
    io.write("  "..ui.B.."N."..ui.R.."  Toggle da tool número N\n")
    io.write("  "..ui.B.."A."..ui.R.."  Desativar todas\n")
    io.write("  "..ui.B.."R."..ui.R.."  Reativar todas\n")
    io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")

    local ch = ui.rdl("Escolha")
    if ui.cancel(ch) then break end
    ch = (ch or ""):match("^%s*(.-)%s*$") or ""
    local upper = ch:upper()

    if upper == "A" then
      local all = {}
      for _, n in ipairs(names) do all[#all + 1] = n end
      save_disabled(config_mod, agent_id, all)
      io.write(ui.RE.."\n  ✅ Todas as tools desativadas para o agente '"..agent_id.."'.\n"..ui.R)
      ui.pause()
    elseif upper == "R" then
      save_disabled(config_mod, agent_id, {})
      io.write(ui.G.."\n  ✅ Todas as tools reativadas para o agente '"..agent_id.."'.\n"..ui.R)
      ui.pause()
    else
      local idx = tonumber(ch)
      if idx and idx >= 1 and idx <= #names then
        local name = names[idx]
        local new_list = {}
        if dset[name] then
          for _, n in ipairs(disabled) do
            if n ~= name then new_list[#new_list + 1] = n end
          end
          io.write(ui.G.."\n  ✅ '"..name.."' reativada.\n"..ui.R)
        else
          for _, n in ipairs(disabled) do new_list[#new_list + 1] = n end
          new_list[#new_list + 1] = name
          table.sort(new_list)
          io.write(ui.RE.."\n  ✅ '"..name.."' desativada (fora do schema).\n"..ui.R)
        end
        save_disabled(config_mod, agent_id, new_list)
        ui.pause()
      end
    end
  end
end

return M
