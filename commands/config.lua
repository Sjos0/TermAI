-- config.lua — Fachada + Entry Point (dentro da TUI)
-- v2.2: Adicionado suporte à opção "7. Conectores" no menu principal.
local ui         = require("commands.models.ui")
local config_mod = require("config")
local c = ui.c
local M = {}
local SEP  = string.rep("─", 45)
local SEP2 = string.rep("─", 30)

local function cls() io.write("\27[2J\27[H"); io.flush() end

local function fmt_tokens(n)
  if not n then return "?" end
  if n >= 1000000 then return string.format("%.2fM", n/1000000)
  elseif n >= 1000 then return string.format("%.1fK", n/1000)
  else return tostring(n) end
end

local function row(label, value, color)
  color = color or c.white
  io.write(string.format("  %s%-22s%s %s%s%s\n",
    c.gray, label, c.reset, color, tostring(value), c.reset))
end

local function load_menu(name)
  return require("commands.config.menus." .. name)
end

function M.run(ctx)
  io.write("\27[?1049h"); io.flush()
  while true do
    cls()
    io.write("\n"..c.bold..c.cyan.."  Configurações"..c.reset.."\n")
    io.write(c.gray.."  "..SEP..c.reset.."\n\n")
    io.write("  "..c.white.."1."..c.reset.."  Memória          "..c.dim.."(Memory Flush)"..c.reset.."\n")
    io.write("  "..c.white.."2."..c.reset.."  Requisições      "..c.dim.."(timeout, tentativas, retry)"..c.reset.."\n")
    io.write("  "..c.white.."3."..c.reset.."  Raciocínio       "..c.dim.."(protocolo de thinking)"..c.reset.."\n")
    io.write("  "..c.white.."4."..c.reset.."  Hooks            "..c.dim.."(permissões, limites do agente)"..c.reset.."\n")
    io.write("  "..c.white.."5."..c.reset.."  Skills           "..c.dim.."(instalar, remover)"..c.reset.."\n")
    io.write("  "..c.white.."6."..c.reset.."  Pesquisa Web     "..c.dim.."(Google Grounding, DuckDuckGo)"..c.reset.."\n")
    io.write("  "..c.white.."7."..c.reset.."  Conectores       "..c.dim.."(MCP Server remoto, Claude.ai)"..c.reset.."\n")
    io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")
    local ch = ui.prompt_read("Escolha")
    if ui.is_cancel(ch) then break end
    if     ch == "1" then load_menu("flush").run(ctx)
    elseif ch == "2" then load_menu("request").run(ctx)
    elseif ch == "3" then load_menu("thinking").run(ctx)
    elseif ch == "4" then load_menu("hooks").run(ctx)
    elseif ch == "5" then load_menu("skills").run(ctx)
    elseif ch == "6" then load_menu("web_tools").run(ctx)
    elseif ch == "7" then load_menu("connectors").run(ctx)
    end
  end
  io.write("\27[?1049l"); io.flush()
end

return M
