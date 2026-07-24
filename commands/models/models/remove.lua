-- remove.lua — Remove um modelo cadastrado, com confirmação. Retorna o novo `active`.
local ui = require("commands.models.ui")
local c  = ui.c
local M = {}

local function remove(models_mod, active)
  local models = models_mod.list()
  if #models == 0 then
    io.write(c.gray .. "  Nenhum modelo cadastrado.\n" .. c.reset)
    return active
  end

  io.write("\n" .. c.bold .. c.cyan .. "  Remover Modelo" .. c.reset .. "\n")
  io.write(c.gray .. "  " .. string.rep("─", 45) .. c.reset .. "\n\n")
  for i, m in ipairs(models) do
    io.write("  " .. c.white .. i .. ". " .. c.reset .. m.ref .. "\n")
  end
  io.write("\n")
  local ch = ui.prompt_read("Número do modelo (0 para voltar)")
  if ui.is_cancel(ch) then return active end
  local idx = tonumber(ch)
  if not idx or idx < 1 or idx > #models then
    io.write(c.red .. "  Opção inválida.\n" .. c.reset)
    return active
  end

  local confirm = ui.prompt_read("Confirmar? (s/n)")
  if not confirm or (confirm:lower() ~= "s" and confirm:lower() ~= "y") then
    io.write(c.gray .. "  Cancelado.\n" .. c.reset)
    return active
  end

  local ok, err = models_mod.remove_model(models[idx].provider, models[idx].id)
  if ok then
    local new_active = active
    if active == models[idx].ref then new_active = "" end
    io.write(c.green .. "  ✅ Modelo removido.\n" .. c.reset)
    return new_active
  else
    io.write(c.red .. "  Erro: " .. tostring(err) .. "\n" .. c.reset)
    return active
  end
end

M.remove = remove
return M
