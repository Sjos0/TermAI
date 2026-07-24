-- config_cli.lua — Fachada + Entry Point
-- Consumidor: main.lua via dofile(BASE.."/commands/config_cli.lua")
local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
package.path = HOME.."/TermAI/?.lua;"..HOME.."/TermAI/?/init.lua;"..package.path

local config_mod = require("config")
local ui         = require("commands.config_cli.ui_utils")

local function load_menu(name)
  return require("commands.config_cli.menus." .. name)
end

while true do
  ui.hdr("TermAI Config")
  io.write("  "..ui.B.."1."..ui.R.."  Requisições      "..ui.DM.."(timeout, tentativas, retry)"..ui.R.."\n")
  io.write("  "..ui.B.."2."..ui.R.."  Memory Flush     "..ui.DM.."(intervalo, ativar/desativar)"..ui.R.."\n")
  io.write("  "..ui.B.."3."..ui.R.."  Raciocínio       "..ui.DM.."(thinking protocol)"..ui.R.."\n")
  io.write("  "..ui.B.."4."..ui.R.."  Hooks            "..ui.DM.."(permissões, limites do agente)"..ui.R.."\n")
  io.write("  "..ui.B.."5."..ui.R.."  Web Tools        "..ui.DM.."(busca na web via Google)"..ui.R.."\n")
  io.write("  "..ui.B.."6."..ui.R.."  Skills           "..ui.DM.."(instalar, remover)"..ui.R.."\n")
  io.write("  "..ui.B.."7."..ui.R.."  Conectores       "..ui.DM.."(MCP Server, Claude.ai)"..ui.R.."\n")
  io.write("  "..ui.B.."0."..ui.R.."  Sair\n\n")

  local ch = ui.rdl("Escolha")
  if ui.cancel(ch) then
    io.write(ui.GR.."  Saindo...\n"..ui.R)
    break
  end
  if     ch == "1" then load_menu("request").run(config_mod, ui)
  elseif ch == "2" then load_menu("flush").run(config_mod, ui)
  elseif ch == "3" then load_menu("thinking").run(config_mod, ui)
  elseif ch == "4" then load_menu("hooks").run(config_mod, ui)
  elseif ch == "5" then load_menu("web_tools").run(config_mod, ui)
  elseif ch == "6" then load_menu("skills").run(config_mod, ui)
  elseif ch == "7" then load_menu("connectors").run(config_mod, ui)
  end
end
