local ui = require("commands.models.ui")
local models = require("models")

return function(ctx)
  local defaults = ctx.cfg.agents.defaults
  defaults.model = defaults.model or { primary = "", fallbacks = {} }
  local model_cfg = defaults.model
  model_cfg.fallbacks = model_cfg.fallbacks or {}
  while true do
    ui.header("Fallback de modelos")
    io.write("  Principal: " .. tostring(model_cfg.primary or "(não definido)") .. "\n")
    for i, ref in ipairs(model_cfg.fallbacks) do io.write("  " .. i .. ". " .. ref .. "\n") end
    io.write("\n  1. Adicionar modelo de fallback\n  2. Remover modelo de fallback\n  0. Voltar\n\n")
    local choice = ui.prompt_read("Escolha")
    if ui.is_cancel(choice) or choice == "0" then break end
    if choice == "1" then
      local available, filtered = models.list(), {}
      for _, item in ipairs(available) do
        local exists = item.ref == model_cfg.primary
        for _, ref in ipairs(model_cfg.fallbacks) do if ref == item.ref then exists = true end end
        if not exists then filtered[#filtered + 1] = item end
      end
      for i, item in ipairs(filtered) do io.write("  " .. i .. ". " .. item.ref .. "\n") end
      local index = tonumber(ui.prompt_read("Modelo (número)"))
      if filtered[index or 0] then
        model_cfg.fallbacks[#model_cfg.fallbacks + 1] = filtered[index].ref
        require("config").set("agents.defaults.model.fallbacks", model_cfg.fallbacks)
      end
    elseif choice == "2" then
      local index = tonumber(ui.prompt_read("Índice a remover"))
      if index and model_cfg.fallbacks[index] then
        table.remove(model_cfg.fallbacks, index)
        require("config").set("agents.defaults.model.fallbacks", model_cfg.fallbacks)
      end
    end
    ui.pause()
  end
end
