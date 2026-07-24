local config_mod = require("config")
local models_mod = require("models")
local ui = require("commands.models.ui")
local models_actions = require("commands.models.models")
local provider_actions = require("commands.models.providers")
local menu = require("commands.models.menu")

config_mod.load()
models_mod.load()

local active = models_mod.get_active()
local sub = arg and arg[2] or nil

local function dispatch()
  if sub == "list" then
    models_actions.list(models_mod, active)
  elseif sub == "set" then
    models_actions.set(config_mod, models_mod, active, arg and arg[3])
  elseif sub == "add" then
    models_actions.add(models_mod, arg and arg[3])
  elseif sub == "remove" then
    models_actions.remove(models_mod, active, arg and arg[3])
  elseif sub == "info" then
    models_actions.info(models_mod, arg and arg[3])
  elseif sub == "add-provider" then
    provider_actions.add_provider(models_mod)
  elseif sub == "remove-provider" then
    provider_actions.remove_provider(models_mod)
  elseif sub == "update-key" then
    provider_actions.update_key(models_mod, arg and arg[3], arg and arg[4])
  elseif sub == "help" or sub == "--help" or sub == "-h" then
    ui.header("TermAI Models — Ajuda")
    io.write("  Uso:\n")
    io.write("    TermAI models              Menu interativo\n")
    io.write("    TermAI models list          Lista todos os modelos\n")
    io.write("    TermAI models set <ref>     Seleciona modelo ativo\n")
    io.write("    TermAI models add [ref]     Adiciona modelo\n")
    io.write("    TermAI models remove [ref]  Remove modelo\n")
    io.write("    TermAI models info <ref>    Detalhes do modelo\n")
    io.write("    TermAI models add-provider  Adiciona provedor\n")
    io.write("    TermAI models remove-provider  Remove provedor\n")
    io.write("    TermAI models update-key    Atualiza API key\n\n")
    io.write("  Exemplos:\n")
    io.write("    TermAI models set openrouter/google/gemma-4-31b-it:free\n")
    io.write("    TermAI models add openrouter/deepseek/deepseek-r1:free\n")
    io.write("    TermAI models info ollama/gemma4:31b-cloud\n\n")
  else
    menu.run(config_mod, models_mod, active)
  end
end

dispatch()
