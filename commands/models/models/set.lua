-- set.lua — Seleciona e ativa um modelo, atualizando a config. Retorna o novo `active`.
local ui = require("commands.models.ui")
local c  = ui.c
local M = {}

local function set(config_mod, models_mod, active, ref)
  if not ref then
    local models = models_mod.list()
    if #models == 0 then
      io.write(c.red .. "  Nenhum modelo cadastrado.\n" .. c.reset)
      return active
    end
    io.write("\n" .. c.bold .. c.cyan .. "  Selecionar Modelo" .. c.reset .. "\n")
    io.write(c.gray .. "  " .. string.rep("─", 45) .. c.reset .. "\n\n")
    for i, m in ipairs(models) do
      local mark = (m.ref == active) and (c.green .. "★") or c.gray .. " "
      io.write("  " .. mark .. " " .. c.reset .. c.white .. i .. ". "
        .. c.reset .. m.ref .. c.gray .. " (" .. ui.fmt_ctx(m.context_window) .. ")\n" .. c.reset)
    end
    io.write("\n")
    local choice = ui.prompt_read("Número do modelo (0 para voltar)")
    if ui.is_cancel(choice) then return active end
    local idx = tonumber(choice)
    if not idx or idx < 1 or idx > #models then
      io.write(c.red .. "  Opção inválida.\n" .. c.reset)
      return active
    end
    ref = models[idx].ref
  end

  local ok, err = models_mod.set_active(ref)
  if not ok then
    io.write(c.red .. "  Erro: " .. tostring(err) .. "\n" .. c.reset)
    return active
  end
  ui.update_config_model(config_mod, ref)
  local resolved = models_mod.resolve(ref)
  io.write(c.green .. "  ✅ Modelo ativo: " .. c.bold
    .. (resolved and resolved.name or ref) .. c.reset .. "\n")
  return ref
end

M.set = set
return M
