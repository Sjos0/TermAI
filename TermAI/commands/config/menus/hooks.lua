-- hooks.lua — Menu Hooks & Automação
local ui          = require("commands.models.ui")
local config_mod  = require("config")
local perms_menu  = require("commands.config.menus.permissions")
local bash_menu   = require("commands.config.menus.bash_patterns")
local c = ui.c
local SEP  = string.rep("─", 45)
local SEP2 = string.rep("─", 30)
local M = {}

local function cls() io.write("\27[2J\27[H"); io.flush() end

local function row(label, value, color)
  color = color or c.white
  io.write(string.format("  %s%-22s%s %s%s%s\n",
    c.gray, label, c.reset, color, tostring(value), c.reset))
end

function M.run(ctx)
  while true do
    cls()
    local hooks_cfg   = ctx.cfg.agents.defaults.hooks or {}
    local max_retries = hooks_cfg.max_tool_retries or 3
    local raw_iter    = ctx.cfg.agents.defaults.maxIter or 20
    local iter_label  = (raw_iter == 0) and (c.yellow.."Ilimitado"..c.reset) or tostring(raw_iter)
    io.write("\n"..c.bold..c.cyan.."  Configurações › Hooks & Automação"..c.reset.."\n")
    io.write(c.gray.."  "..SEP..c.reset.."\n\n")
    io.write(c.gray.."  ── Escudo Anti-Burrice "..SEP2..c.reset.."\n")
    row("Max tentativas de erro:", tostring(max_retries).."  "..c.dim.."(1 – 10)"..c.reset)
    io.write("\n")
    io.write(c.gray.."  ── Limites do Agente "..SEP2..c.reset.."\n")
    row("Max iterações de tools:", iter_label)
    io.write("\n")
    io.write(c.gray.."  ── Opções "..SEP2..c.reset.."\n")
    io.write("  "..c.white.."1."..c.reset.."  Alterar max tentativas de erro  "..c.dim.."(padrão: 3)"..c.reset.."\n")
    io.write("  "..c.white.."2."..c.reset.."  Alterar max iterações de tools  "..c.dim.."(0 = ilimitado)"..c.reset.."\n")
    io.write("  "..c.white.."3."..c.reset.."  Gerenciar permissões de ferramentas\n")
    io.write("  "..c.white.."4."..c.reset.."  Padrões Bash  "..c.dim.."(comandos sempre permitidos)"..c.reset.."\n")
    io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")
    local ch = ui.prompt_read("Escolha")
    if ui.is_cancel(ch) then break end
    if ch == "1" then
      local s = ui.prompt_read("Max tentativas de erro (1 – 10, padrão: 3)")
      local v = tonumber(s)
      if v and v >= 1 and v <= 10 then
        if not ctx.cfg.agents.defaults.hooks then ctx.cfg.agents.defaults.hooks = {} end
        ctx.cfg.agents.defaults.hooks.max_tool_retries = v
        config_mod.set("agents.defaults.hooks.max_tool_retries", v)
        io.write(c.green.."\n  ✅ Max tentativas de erro: "..v.."\n"..c.reset)
      else io.write(c.red.."\n  ❌ Inválido (1 – 10).\n"..c.reset) end
      ui.pause()
    elseif ch == "2" then
      io.write(c.dim.."  0 = ilimitado  |  número positivo = limite fixo\n\n"..c.reset)
      local s = ui.prompt_read("Max iterações (0 = ilimitado, padrão: 20)")
      local v = tonumber(s)
      if v and v >= 0 then
        ctx.cfg.agents.defaults.maxIter = v
        ctx.MAX_ITER = v
        config_mod.set("agents.defaults.maxIter", v)
        local lbl = (v == 0) and "Ilimitado" or tostring(v)
        io.write(c.green.."\n  ✅ Max iterações: "..lbl.."\n"..c.reset)
        if v == 0 then
          io.write(c.yellow.."  ⚠️  Sem limite: monitore o consumo de tokens.\n"..c.reset)
        end
      else io.write(c.red.."\n  ❌ Inválido.\n"..c.reset) end
      ui.pause()
    elseif ch == "3" then
      perms_menu.run(ctx)
    elseif ch == "4" then
      bash_menu.run(ctx)
    end
  end
end

return M
