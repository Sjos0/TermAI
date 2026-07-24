-- thinking.lua — Menu Raciocínio Estimulado
local ui         = require("commands.models.ui")
local config_mod = require("config")
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

local function save_tp(ctx, key, val)
  if not ctx.cfg.agents.defaults.thinking_protocol then
    ctx.cfg.agents.defaults.thinking_protocol = {}
  end
  ctx.cfg.agents.defaults.thinking_protocol[key] = val
  config_mod.set("agents.defaults.thinking_protocol." .. key, val)
end

function M.run(ctx)
  while true do
    cls()
    local tp      = ctx.cfg.agents.defaults.thinking_protocol or {}
    local enabled = tp.enabled == true
    local effort  = tp.effort or "medium"
    io.write("\n"..c.bold..c.cyan.."  Configurações › Raciocínio Estimulado"..c.reset.."\n")
    io.write(c.gray.."  "..SEP..c.reset.."\n\n")
    io.write(c.dim..[[  Injeta um protocolo de raciocínio no System Prompt.
  Para modelos SEM reasoning nativo: força o uso de <think>...</think>.
  Para modelos COM reasoning nativo: reforça o nível de profundidade.
  Reinicie a TUI após alterar para aplicar ao system prompt.
]]..c.reset.."\n")
    io.write(c.gray.."  ── Status "..SEP2..c.reset.."\n")
    row("Protocolo:", enabled and (c.green.."✅ Ativo") or (c.red.."❌ Desativado"), "")
    row("Nível:", effort)
    io.write("\n"..c.gray.."  ── Opções "..SEP2..c.reset.."\n")
    io.write("  "..c.white.."1."..c.reset.."  "..(enabled and (c.red.."Desativar") or (c.green.."Ativar"))..c.reset.." Protocolo\n")
    io.write("  "..c.white.."2."..c.reset.."  Alterar nível  "..c.dim.."(low / medium / high)"..c.reset.."\n")
    io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")
    local ch = ui.prompt_read("Escolha")
    if ui.is_cancel(ch) then break end
    if ch == "1" then
      local new = not enabled
      save_tp(ctx, "enabled", new)
      io.write(new and (c.green.."\n  ✅ Ativado. Reinicie a TUI.\n"..c.reset)
                    or (c.red.."\n  ❌ Desativado. Reinicie a TUI.\n"..c.reset))
      ui.pause()
    elseif ch == "2" then
      io.write("  "..c.white.."1."..c.reset.."  low     "..c.dim.."(rápido, 2-4 linhas)"..c.reset.."\n")
      io.write("  "..c.white.."2."..c.reset.."  medium  "..c.dim.."(passo a passo, 1-2 parágrafos)"..c.reset.."\n")
      io.write("  "..c.white.."3."..c.reset.."  high    "..c.dim.."(exaustivo, máxima profundidade)"..c.reset.."\n\n")
      local lch = ui.prompt_read("Nível")
      local levels = {["1"]="low", ["2"]="medium", ["3"]="high"}
      if levels[lch] then
        save_tp(ctx, "effort", levels[lch])
        io.write(c.green.."\n  ✅ Nível: "..levels[lch]..". Reinicie a TUI.\n"..c.reset)
      else io.write(c.red.."\n  ❌ Inválido.\n"..c.reset) end
      ui.pause()
    end
  end
end

return M
