-- bash_patterns.lua — Menu Padrões Bash
local ui = require("commands.models.ui")
local c  = ui.c
local core = require("ui.core")
-- Réguas responsivas (#331): função, não valor — core.tw() é lido a cada uso,
-- então girar o celular já muda o separador. `prefixo`/`usado` é o que já
-- ocupou a linha; a régua encolhe o quanto precisar para não estourar tw.
local function SEP(usado)    return core.regua(45, usado or 2) end
local function SEP2(prefixo) return core.regua(30, #(prefixo or "")) end
local M = {}

local function cls() io.write("\27[2J\27[H"); io.flush() end

function M.run(ctx)
  local bp = require("agent.hooks.bash_patterns")
  while true do
    cls()
    local patterns = bp.list()
    io.write("\n"..c.bold..c.cyan.."  Configurações › Hooks › Padrões Bash"..c.reset.."\n")
    io.write(c.gray.."  "..SEP()..c.reset.."\n\n")
    io.write(c.dim.."  Bash commands que executam sem pedir permissão.\n\n"..c.reset)
    if #patterns == 0 then
      io.write(c.gray.."  (nenhum padrão salvo)\n\n"..c.reset)
    else
      for i, p in ipairs(patterns) do
        io.write(string.format("  %s%d.%s  %s\"%s\"%s\n",
          c.white, i, c.reset, c.green, p, c.reset))
      end
      io.write("\n")
    end
    io.write(c.gray.."  ── Opções "..SEP2("  ── Opções ")..c.reset.."\n")
    io.write("  "..c.white.."A."..c.reset.."  Adicionar padrão\n")
    if #patterns > 0 then
      io.write("  "..c.white.."R."..c.reset.."  Remover (número do padrão)\n")
    end
    io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")
    local ch = ui.prompt_read("Escolha")
    if ui.is_cancel(ch) then break end
    if ch:lower() == "a" then
      local s = ui.prompt_read("Padrão (ex: luac -p, git, date +)")
      if s and s ~= "" then
        bp.add_pattern(s)
        io.write(c.green.."\n  [OK] Adicionado: \""..s.."\"\n"..c.reset)
      else io.write(c.gray.."\n  Cancelado.\n"..c.reset) end
      ui.pause()
    else
      local idx = tonumber(ch)
      if idx and patterns[idx] then
        bp.remove_pattern(patterns[idx])
        io.write(c.green.."\n  [OK] Removido: \""..patterns[idx].."\"\n"..c.reset)
      else io.write(c.red.."\n  [FAIL] Opção inválida.\n"..c.reset) end
      ui.pause()
    end
  end
end

return M
