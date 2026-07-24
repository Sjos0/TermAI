-- flush.lua — Menu Memory Flush
local ui         = require("commands.models.ui")
local config_mod = require("config")
local mf         = require("memoryflush")
local session    = require("session")
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

local function fmt_tokens(n)
  if not n then return "?" end
  if n >= 1000000 then return string.format("%.2fM", n/1000000)
  elseif n >= 1000 then return string.format("%.1fK", n/1000)
  else return tostring(n) end
end

function M.run(ctx)
  while true do
    cls()
    local comp    = ctx.compaction
    local enabled = comp.flush_enabled ~= false
    local limit   = comp.flush_tokens or 40000
    local mf_cfg  = {
      max_contexto = ctx.active.context_window,
      limites = { flush_tokens=limit, compactacao_pct=comp.compactacao_pct or 0.9, flush_enabled=enabled }
    }
    local estado = mf.estado(ctx.tokens, mf_cfg)
    io.write("\n" .. c.bold .. c.cyan .. "  Configurações › Memória › Memory Flush" .. c.reset .. "\n")
    io.write(c.gray .. "  " .. SEP .. c.reset .. "\n\n")
    io.write(c.gray .. "  ── Contexto " .. SEP2 .. c.reset .. "\n")
    row("Agente:", mf.get_agent_id(), c.cyan)
    row("State file:", mf.get_state_file(), c.dim .. c.gray)
    row("Sessão:", session.current(), c.gray)
    io.write("\n")
    io.write(c.gray .. "  ── Status " .. SEP2 .. c.reset .. "\n")
    row("Flush:", enabled and (c.green.."✅ Ativo") or (c.red.."❌ Desativado"), "")
    row("Intervalo:", fmt_tokens(limit) .. " tokens")
    row("Último flush:", fmt_tokens(estado.ultimo) .. " tokens", c.gray)
    row("Tokens agora:", fmt_tokens(ctx.tokens) .. " tokens")
    if enabled then
      local faltam = estado.faltam
      local col = faltam < (limit * 0.2) and c.yellow or c.white
      row("Próximo flush:", fmt_tokens(estado.proximo) .. " tokens"
        .. c.gray .. "  (faltam " .. fmt_tokens(faltam) .. ")" .. c.reset, col)
    end
    io.write("\n")
    io.write(c.gray .. "  ── Opções " .. SEP2 .. c.reset .. "\n")
    io.write("  "..c.white.."1."..c.reset.."  "..(enabled and (c.red.."Desativar") or (c.green.."Ativar"))..c.reset.." Flush\n")
    io.write("  "..c.white.."2."..c.reset.."  "..c.gray.."Alterar intervalo"..c.reset..c.dim.."  ("..fmt_tokens(limit)..")"..c.reset.."\n")
    io.write("  "..c.white.."3."..c.reset.."  "..c.gray.."Resetar estado"..c.reset..c.dim.."  (próximo em "..fmt_tokens(limit)..")"..c.reset.."\n")
    io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")
    local ch = ui.prompt_read("Escolha")
    if ui.is_cancel(ch) then break end
    if ch == "1" then
      local new = not enabled
      ctx.compaction.flush_enabled = new
      config_mod.set("agents.defaults.compaction.flush_enabled", new)
      io.write(new and (c.green.."\n  ✅ Ativado.\n"..c.reset) or (c.red.."\n  ❌ Desativado.\n"..c.reset))
      ui.pause()
    elseif ch == "2" then
      local s = ui.prompt_read("Novo intervalo em tokens (mín: 5000)")
      local v = tonumber(s and s:gsub("[^%d]",""))
      if v and v >= 5000 then
        ctx.compaction.flush_tokens = v
        config_mod.set("agents.defaults.compaction.flush_tokens", v)
        io.write(c.green.."\n  ✅ Intervalo: "..fmt_tokens(v).."\n"..c.reset)
      else io.write(c.red.."\n  ❌ Inválido.\n"..c.reset) end
      ui.pause()
    elseif ch == "3" then
      local confirm = ui.prompt_read("Resetar contador? (s/N)")
      if confirm and confirm:lower() == "s" then
        mf.marcar_flush(0)
        io.write(c.green.."\n  ✅ Resetado.\n"..c.reset)
      else io.write(c.gray.."\n  Cancelado.\n"..c.reset) end
      ui.pause()
    end
  end
end

return M
