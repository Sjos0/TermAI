-- commands/config/menus/connectores.lua — Menu TUI (em desenvolvimento).
local ui = require("commands.models.ui")
local c = ui.c
local M = {}
function M.run(ctx)
  io.write("\27[2J\27[H")
  io.write("\n"..c.bold..c.cyan.."  Config > Conectores (MCP)"..c.reset.."\n\n")
  io.write("  "..c.yellow.."⚙️  Em desenvolvimento..."..c.reset.."\n\n")
  io.write("  Instalar MCPs de fora para dentro do TermAI.\n")
  io.write("  "..c.gray.."Status: Streamable HTTP validado (21/21)"..c.reset.."\n")
  io.write("  "..c.gray.."Pendente: OAuth + Cliente MCP nativo"..c.reset.."\n\n")
  io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")
  ui.prompt_read("Escolha")
end
return M
