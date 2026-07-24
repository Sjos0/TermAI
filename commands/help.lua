local HOME = os.getenv("HOME") or "/data/data/com.termux/files/home"
local BASE = HOME .. "/TermAI"

local function get_version()
  local f = io.open(BASE .. "/VERSION", "r")
  if f then
    local v = f:read("*a"):match("^%s*(.-)%s*$")
    f:close()
    return v
  end
  return "dev"
end

local version = get_version()

io.write("\n")
io.write("\27[1m\27[38;5;39m  TermAI\27[0m\27[38;5;245m v" .. version .. "\27[0m\n")
io.write("\27[38;5;245m  Agente autônomo de terminal para Termux\27[0m\n")
io.write("\n")
io.write("\27[1m  Uso:\27[0m\n")
io.write("    TermAI <comando>\n")
io.write("\n")
io.write("\27[1m  Comandos:\27[0m\n")
io.write("    \27[38;5;114mtui\27[0m        Inicia a interface interativa (chat com IA)\n")
io.write("    \27[38;5;114mstatus\27[0m     Mostra status do sistema e configuração\n")
io.write("    \27[38;5;114mmodels\27[0m     Gerencia modelos e provedores de IA\n")
io.write("    \27[38;5;114mhelp\27[0m       Mostra esta mensagem\n")
io.write("\n")
io.write("\27[1m  Exemplos:\27[0m\n")
io.write("    TermAI tui          \27[90m# inicia o chat\27[0m\n")
io.write("    TermAI status       \27[90m# verifica config\27[0m\n")
io.write("    TermAI models       \27[90m# gerencia modelos\27[0m\n")
io.write("\n")
