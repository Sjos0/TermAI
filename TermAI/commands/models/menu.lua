local ui = require("commands.models.ui")
local models_actions = require("commands.models.models")
local provider_actions = require("commands.models.providers")
local c = ui.c
local M = {}

function M.run(config_mod, models_mod, active)
  while true do
    io.write("\27[2J\27[H"); io.flush()
    active = models_mod.get_active()
    ui.header("Gerenciador de Modelos")

    if active and active ~= "" then
      io.write(c.bold .. "  Modelo ativo: " .. c.green .. active .. c.reset .. "\n\n")
    else
      io.write(c.yellow .. "  Nenhum modelo ativo selecionado.\n\n" .. c.reset)
    end

    io.write("  " .. c.white .. "1." .. c.reset .. " Listar modelos\n")
    io.write("  " .. c.white .. "2." .. c.reset .. " Selecionar modelo ativo\n")
    io.write("  " .. c.white .. "3." .. c.reset .. " Adicionar modelo\n")
    io.write("  " .. c.white .. "4." .. c.reset .. " Remover modelo\n")
    io.write("  " .. c.white .. "5." .. c.reset .. " Detalhes de um modelo\n")
    io.write("  " .. c.white .. "6." .. c.reset .. " Adicionar provedor\n")
    io.write("  " .. c.white .. "7." .. c.reset .. " Remover provedor\n")
    io.write("  " .. c.white .. "8." .. c.reset .. " Atualizar API Key\n")
    io.write("  " .. c.white .. "0." .. c.reset .. " Sair\n\n")

    local ch = ui.prompt_read("Escolha")

    if not ch then io.write("\n"); break end

    if ch == "1" then
      models_actions.list(models_mod, active)
      ui.pause()
    elseif ch == "2" then
      active = models_actions.set(config_mod, models_mod, active)
      ui.pause()
    elseif ch == "3" then
      models_actions.add(models_mod)
      ui.pause()
    elseif ch == "4" then
      active = models_actions.remove(models_mod, active)
      ui.pause()
    elseif ch == "5" then
      models_actions.info(models_mod)
      ui.pause()
    elseif ch == "6" then
      provider_actions.add_provider(models_mod)
      ui.pause()
    elseif ch == "7" then
      local new_active = provider_actions.remove_provider(models_mod)
      if new_active ~= nil then active = new_active end
      ui.pause()
    elseif ch == "8" then
      provider_actions.update_key(models_mod)
      ui.pause()
    elseif ch == "0" then
      io.write(c.gray .. "  Saindo...\n\n" .. c.reset)
      break
    else
      io.write(c.red .. "  Opção inválida.\n" .. c.reset)
      ui.pause()
    end
  end
end

return M
