-- remove.lua — Remove um provedor cadastrado, com confirmação do usuário.
local ui = require("commands.models.ui")
local c  = ui.c
local M = {}

local function remove(models_mod)
  local providers = models_mod.list_providers()
  if #providers == 0 then
    io.write(c.gray .. "  Nenhum provedor cadastrado.\n" .. c.reset)
    return
  end

  ui.header("Remover Provedor")
  for i, p in ipairs(providers) do
    io.write("  " .. c.white .. i .. ". " .. c.reset .. p.id
      .. c.gray .. " (" .. p.model_count .. " modelos)\n" .. c.reset)
  end
  io.write("\n")
  local ch = ui.prompt_read("Número do provedor (0 para voltar)")
  if ui.is_cancel(ch) then return end
  local idx = tonumber(ch)
  if not idx or idx < 1 or idx > #providers then
    io.write(c.red .. "  Opção inválida.\n" .. c.reset); return
  end

  local confirm = ui.prompt_read("Remover '" .. providers[idx].id .. "'? (s/N)")
  if not confirm or confirm:lower() ~= "s" then
    io.write(c.gray .. "  Cancelado.\n" .. c.reset); return
  end

  local ok, err = models_mod.remove_provider(providers[idx].id)
  if ok then
    io.write(c.green .. "  ✅ Provedor removido.\n" .. c.reset)
  else
    io.write(c.red .. "  Erro: " .. tostring(err) .. "\n" .. c.reset)
  end
end

M.remove = remove
return M
