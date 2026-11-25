-- commands/config/menus/subagents.lua — CRUD do modelo default/fallbacks de subagentes (Issue #373).
local ui = require("commands.models.ui")
local models = require("models")
local c = ui.c
local M = {}

local function ensure_block(cfg)
  cfg.agents = cfg.agents or {}
  cfg.agents.defaults = cfg.agents.defaults or {}
  local d = cfg.agents.defaults
  d.subagents = d.subagents or {}
  d.subagents.model = d.subagents.model or { primary = "", fallbacks = {} }
  d.subagents.model.fallbacks = d.subagents.model.fallbacks or {}
  return d.subagents.model
end

local function global_primary(cfg)
  local m = cfg.agents and cfg.agents.defaults and cfg.agents.defaults.model
  return (m and m.primary and m.primary ~= "") and m.primary or "(não definido)"
end

function M.run(ctx)
  while true do
    local model_cfg = ensure_block(ctx.cfg)
    local primary = model_cfg.primary
    local primary_label = (type(primary) == "string" and primary ~= "") and primary
      or ("herda primary do chat: " .. global_primary(ctx.cfg))
    ui.header("Subagentes › Modelo")
    io.write("  Primary: " .. primary_label .. "\n")
    if #(model_cfg.fallbacks or {}) == 0 then
      io.write(c.gray .. "  Fallbacks: (herda lista global se vazia)\n" .. c.reset)
    else
      for i, ref in ipairs(model_cfg.fallbacks) do
        io.write("  " .. i .. ". " .. ref .. "\n")
      end
    end
    io.write("\n  1. Definir primary\n  2. Limpar primary (herdar global)\n"
      .. "  3. Adicionar fallback\n  4. Remover fallback\n  0. Voltar\n\n")
    local choice = ui.prompt_read("Escolha")
    if ui.is_cancel(choice) or choice == "0" then break end
    if choice == "1" then
      local available = models.list() or {}
      for i, item in ipairs(available) do
        io.write("  " .. i .. ". " .. item.ref .. "\n")
      end
      local index = tonumber(ui.prompt_read("Modelo (número)"))
      if available[index or 0] then
        model_cfg.primary = available[index].ref
        require("config").set("agents.defaults.subagents.model.primary", model_cfg.primary)
        io.write(c.green .. "  [OK] Primary de subagente: " .. model_cfg.primary .. "\n" .. c.reset)
      end
    elseif choice == "2" then
      model_cfg.primary = ""
      require("config").set("agents.defaults.subagents.model.primary", "")
      io.write(c.green .. "  [OK] Primary limpo — herda o do chat.\n" .. c.reset)
    elseif choice == "3" then
      local available, filtered = models.list() or {}, {}
      for _, item in ipairs(available) do
        local exists = item.ref == model_cfg.primary
        for _, ref in ipairs(model_cfg.fallbacks) do if ref == item.ref then exists = true end end
        if not exists then filtered[#filtered + 1] = item end
      end
      for i, item in ipairs(filtered) do io.write("  " .. i .. ". " .. item.ref .. "\n") end
      local index = tonumber(ui.prompt_read("Modelo (número)"))
      if filtered[index or 0] then
        model_cfg.fallbacks[#model_cfg.fallbacks + 1] = filtered[index].ref
        require("config").set("agents.defaults.subagents.model.fallbacks", model_cfg.fallbacks)
      end
    elseif choice == "4" then
      local index = tonumber(ui.prompt_read("Índice a remover"))
      if index and model_cfg.fallbacks[index] then
        table.remove(model_cfg.fallbacks, index)
        require("config").set("agents.defaults.subagents.model.fallbacks", model_cfg.fallbacks)
      end
    end
    ui.pause()
  end
end

return M
