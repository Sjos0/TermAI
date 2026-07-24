-- TermAI — CLI entry point
local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BASE = HOME .. "/TermAI"

package.path = BASE .. "/?.lua;"
            .. BASE .. "/?/init.lua;"
            .. BASE .. "/?.lua;"
            .. package.path

local arg_cmd = arg and arg[1] or nil

local function show_banner()
  local f = io.open(BASE .. "/banner.txt", "r")
  if f then io.write(f:read("*a") .. "\n"); f:close() end
end

local commands = {
  tui     = BASE .. "/commands/tui.lua",
  status  = BASE .. "/commands/status.lua",
  models  = BASE .. "/commands/models.lua",
  restart = BASE .. "/commands/restart.lua",
  config  = BASE .. "/commands/config_cli.lua",
  npx     = BASE .. "/tools/skills/skills_installer/cli.lua",
  skills = BASE .. "/tools/skills/skills_installer/cli.lua",
}

-- Sem argumento: banner + lista de comandos CLI
if not arg_cmd or arg_cmd == "" then
  show_banner()
  local W = "\27[1m"; local R = "\27[0m"
  local G = "\27[38;5;114m"; local D = "\27[2m"; local C = "\27[38;5;80m"
  io.write(C .. "  Comandos disponíveis:\n\n" .. R)
  io.write("  " .. W .. "TermAI" .. R
    .. "             " .. D .. "Exibe este menu\n" .. R)
  io.write("  " .. W .. "TermAI tui" .. R
    .. "          " .. D .. "Inicia o agente interativo\n" .. R)
  io.write("  " .. W .. "TermAI config" .. R
    .. "       " .. D .. "Configurações (timeout, hooks, modelos...)\n" .. R)
  io.write("  " .. W .. "TermAI models" .. R
    .. "       " .. D .. "Gerenciar provedores e modelos de IA\n" .. R)

  io.write("  " .. W .. "TermAI status" .. R
    .. "       " .. D .. "Status da sessão ativa\n" .. R)
  io.write("  " .. W .. "TermAI help" .. R
    .. "         " .. D .. "Ajuda detalhada\n" .. R)
  io.write("\n")
  return
end

-- Help: banner + help detalhado
if arg_cmd == "help" or arg_cmd == "--help" or arg_cmd == "-h" then
  show_banner()
  dofile(BASE .. "/commands/help.lua")
  return
end

-- Banner antes de qualquer comando externo (não na TUI que tem o seu)
if arg_cmd ~= "tui" then
  show_banner()
end

local cmd_path = commands[arg_cmd]
if cmd_path then
  if arg_cmd == "npx" or arg_cmd == "skills" then
    local mod = dofile(cmd_path)
    if mod and mod.run then mod.run(arg) end
  else
    dofile(cmd_path)
  end
else
  io.write("\27[31m[ERRO]\27[0m Comando desconhecido: '" .. arg_cmd .. "'\n")
  io.write("Use \27[1mTermAI\27[0m para ver os comandos disponíveis.\n")
  os.exit(1)
end
