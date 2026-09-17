-- commands/config/menus/tools.lua
-- Menu TUI: desativar/reativar tools por agente ativo (Issue #32).
-- Lista sempre a partir de tools.registry — nunca hardcodar nomes.
local ui         = require("commands.models.ui")
local config_mod = require("config")
local tools_mod  = require("tools")
local c = ui.c
local SEP  = string.rep("─", 45)
local SEP2 = string.rep("─", 30)
local M = {}

local function cls() io.write("\27[2J\27[H"); io.flush() end

local function resolve_agent_id(cfg)
  return (cfg.agents and cfg.agents.list and cfg.agents.list[1] and
          cfg.agents.list[1].id) or "main"
end

local function get_disabled_list(cfg, agent_id)
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

--- Persiste disabled_tools no entry do agente por id (não por índice fixo).
local function save_disabled(cfg, agent_id, list, ctx)
  local agents = cfg.agents and cfg.agents.list or {}
  for i, agent in ipairs(agents) do
    if agent.id == agent_id then
      agents[i].disabled_tools = list
      break
    end
  end
  -- Atualiza ctx em memória para o processo atual refletir a mudança.
  if ctx then
    ctx.cfg = cfg
    local set = {}
    for _, n in ipairs(list) do set[n] = true end
    ctx.disabled_tools = set
  end
  -- Persiste a lista inteira via set no path do array (store reescreve o JSON).
  config_mod.set("agents.list", agents)
  return true
end

local function sorted_tool_names()
  local names = {}
  for name in pairs(tools_mod.registry) do
    names[#names + 1] = name
  end
  table.sort(names)
  return names
end

function M.run(ctx)
  while true do
    cls()
    local cfg = config_mod.load()
    if ctx and ctx.cfg then cfg = ctx.cfg end
    local agent_id = (ctx and ctx.agent_id) or resolve_agent_id(cfg)
    local disabled = get_disabled_list(cfg, agent_id)
    local dset = to_set(disabled)
    local names = sorted_tool_names()

    io.write("\n"..c.bold..c.cyan.."  Configurações › Tools (agente: "..agent_id..")"..c.reset.."\n")
    io.write(c.gray.."  "..SEP..c.reset.."\n\n")
    io.write(c.dim.."  Desativar remove a tool do schema do modelo.\n")
    io.write("  Permissões (ask/block) são outra coisa — só valem para tools ativas.\n"..c.reset.."\n")

    io.write(c.gray.."  ── Tools "..SEP2..c.reset.."\n")
    for i, name in ipairs(names) do
      local data = tools_mod.registry[name]
      local desc = (data and data.desc) or ""
      if #desc > 40 then desc = desc:sub(1, 37) .. "..." end
      local status = dset[name]
        and (c.red.."❌ desativada"..c.reset)
        or  (c.green.."✅ ativa"..c.reset)
      io.write(string.format("  %s%2d.%s  %-18s %s  %s%s%s\n",
        c.white, i, c.reset, name, status, c.dim, desc, c.reset))
    end

    io.write("\n"..c.gray.."  ── Ações "..SEP2..c.reset.."\n")
    io.write("  "..c.white.."N."..c.reset.."  Toggle da tool número N\n")
    io.write("  "..c.white.."A."..c.reset.."  Desativar todas\n")
    io.write("  "..c.white.."R."..c.reset.."  Reativar todas\n")
    io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")

    local ch = ui.prompt_read("Escolha")
    if ui.is_cancel(ch) then break end
    ch = (ch or ""):match("^%s*(.-)%s*$") or ""
    local upper = ch:upper()

    if upper == "A" then
      local all = {}
      for _, n in ipairs(names) do all[#all + 1] = n end
      save_disabled(cfg, agent_id, all, ctx)
      io.write(c.red.."\n  ✅ Todas as tools desativadas para o agente '"..agent_id.."'.\n"..c.reset)
      ui.pause()
    elseif upper == "R" then
      save_disabled(cfg, agent_id, {}, ctx)
      io.write(c.green.."\n  ✅ Todas as tools reativadas para o agente '"..agent_id.."'.\n"..c.reset)
      ui.pause()
    else
      local idx = tonumber(ch)
      if idx and idx >= 1 and idx <= #names then
        local name = names[idx]
        local new_list = {}
        if dset[name] then
          -- reativar: remover da lista
          for _, n in ipairs(disabled) do
            if n ~= name then new_list[#new_list + 1] = n end
          end
          io.write(c.green.."\n  ✅ '"..name.."' reativada.\n"..c.reset)
        else
          -- desativar: adicionar
          for _, n in ipairs(disabled) do new_list[#new_list + 1] = n end
          new_list[#new_list + 1] = name
          table.sort(new_list)
          io.write(c.red.."\n  ✅ '"..name.."' desativada (fora do schema).\n"..c.reset)
        end
        save_disabled(cfg, agent_id, new_list, ctx)
        ui.pause()
      end
    end
  end
end

return M
