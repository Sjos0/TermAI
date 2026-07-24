-- commands/config_cli/menus/connectores.lua — Menu CLI (em desenvolvimento).
local ui = require("commands.config_cli.ui_utils")
local M = {}
function M.run(ctx)
  ui.hdr("Conectores (MCP)")
  io.write("\n  "..ui.YL.."⚙️  Em desenvolvimento..."..ui.R.."\n\n")
  io.write("  Instalar MCPs de fora para dentro do TermAI.\n")
  io.write("  Status: Streamable HTTP validado (21/21)\n")
  io.write("  Pendente: OAuth + Cliente MCP nativo\n\n")
  io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")
  ui.rdl("Escolha")
end
return M
