-- commands/config_cli/menus/request/parte_1.lua — exporta: run.
return function(M, N)
  local sub = require("commands.config_cli.menus.request.submenus")


  function M.run(config_mod, ui)
    while true do
      local cfg  = ui.get_cfg()
      local req  = cfg.agents.defaults.request or {}
      local tout    = req.timeout      or 180
      local idle    = req.idle_timeout or 30
      local retries = req.max_retries  or 10
      local mode    = req.retry_mode   or "exponential"
      local static  = req.retry_static or 5
      local rmax    = req.retry_max    or 30
      local wt      = req.wait_timeout or 0
      local req_mode = req.mode or ((wt > 0) and "buffer" or "stream")

      ui.hdr("TermAI Config › Requisições")
      io.write(ui.GR.."  ── Status atual "..ui.SEP2("  ── Status atual ")..ui.R.."\n")
      ui.row("Modo:", req_mode == "buffer"
                and (ui.G.."buffer"..ui.R..ui.DM.."  (wrapper - resiliente a rede)"..ui.R)
                or  (ui.G.."stream"..ui.R..ui.DM.."  (curl direto - tokens em tempo real)"..ui.R))
      ui.row("Max Time (Total):",  tout == 999999 and "sem limite" or (tout.."s"))
      ui.row("Idle Time (Ocioso):", idle.."s")
      ui.row("Wait timeout:", wt > 0 and (wt.."s  "..ui.DM.."(buffer: watchdog do wrapper)"..ui.R)
                           or (ui.DM.."desativado"..ui.R))
      ui.row("Max tentativas:", tostring(retries))
      ui.row("Modo retry:",    mode)
      if mode == "static" then
        ui.row("Wait estático:", static.."s")
      else
        ui.row("Wait máximo:",  rmax.."s  "..ui.DM.."(dobra a cada erro até este limite)"..ui.R)
      end
      ui.row("Reasoning Effort (OpenRouter):", req.reasoning_effort or "medium", ui.CY)
      ui.row("Thinking Effort (OpenCode Zen):", (cfg.agents.defaults.thinkingEffort or "high"), ui.CY)
      io.write("\n"..ui.GR.."  ── Opções "..ui.SEP2("  ── Opções ")..ui.R.."\n")
      ui.option("1", "Alterar Max Time (Total)", "(padrão: 180s | máx: 300s)")
      ui.option("2", "Alterar Idle Time (Ocioso)", "(padrão: 30s | máx: 180s)")
      ui.option("3", "Alterar max tentativas", "(padrão: 10)")
      ui.option("4", "Modo retry", "(exponential | static)")
      ui.option("5", "Restaurar padrões")
      ui.option("6", "Modo de Requisicao", "(stream | buffer)")
      ui.option("7", "Alterar wait timeout", "(padrao: 25s | buffer)")
      ui.option("8", "Reasoning Effort (OpenRouter)", "(6 níveis — só afeta modelos com reasoning_style=openrouter)")
      ui.option("9", "Thinking Effort (OpenCode Zen)", "(3 níveis — afeta hy3-free e outros com reasoning_style=reasoning_effort)")
      ui.option("10", "Fallback (API Keys, modelos e transparência)")
      ui.option("0", "Voltar")
      io.write("\n")
      local ch = ui.rdl("Escolha")
      if ui.cancel(ch) then break end

      if ch == "1" then
        local s = ui.rdl("Max Time (Total) em segundos (1 a 300)")
        local v = tonumber(s)
        if v and v >= 1 and v <= 300 then
          config_mod.set("agents.defaults.request.timeout", v)
          io.write(ui.G.."\n  [OK] Max Time: "..v.."s\n"..ui.R)
        else io.write(ui.RE.."\n  [FAIL] Inválido. O limite é 300s.\n"..ui.R) end
        ui.pause()

      elseif ch == "2" then
        local s = ui.rdl("Idle Time (Ocioso) em segundos (1 a 180)")
        local v = tonumber(s)
        if v and v >= 1 and v <= 180 then
          config_mod.set("agents.defaults.request.idle_timeout", v)
          io.write(ui.G.."\n  [OK] Idle Time: "..v.."s\n"..ui.R)
        else io.write(ui.RE.."\n  [FAIL] Inválido. O limite é 180s.\n"..ui.R) end
        ui.pause()

      elseif ch == "3" then
        local s = ui.rdl("Número de tentativas (1-20)")
        local v = tonumber(s)
        if v and v >= 1 and v <= 20 then
          config_mod.set("agents.defaults.request.max_retries", v)
          io.write(ui.G.."\n  [OK] Max tentativas: "..v.."\n"..ui.R)
        else io.write(ui.RE.."\n  [FAIL] Inválido (1-20).\n"..ui.R) end
        ui.pause()

      elseif ch == "4" then
        sub.modo_retry(config_mod, ui, rmax)
      elseif ch == "5" then
        sub.restaurar(config_mod, ui)
      elseif ch == "6" then
        sub.modo_requisicao(config_mod, ui)
      elseif ch == "7" then
        sub.wait_timeout(config_mod, ui)
      elseif ch == "8" then
        sub.reasoning_effort(config_mod, ui)
      elseif ch == "9" then
        sub.thinking_effort(config_mod, ui)
      elseif ch == "10" then
        require("commands.config_cli.menus.request.fallback").run(config_mod, ui)
      end
    end
  end
end
