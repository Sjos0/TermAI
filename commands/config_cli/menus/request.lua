-- commands/config_cli/menus/request.lua
-- Menu de Requisicoes: timeout, retries, mode, reasoning effort.
local M = {}

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
    io.write(ui.GR.."  ── Status atual "..ui.SEP2..ui.R.."\n")
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
    io.write("\n"..ui.GR.."  ── Opções "..ui.SEP2..ui.R.."\n")
    io.write("  "..ui.B.."1."..ui.R.."  Alterar Max Time (Total)   "..ui.DM.."(padrão: 180s | máx: 300s)"..ui.R.."\n")
    io.write("  "..ui.B.."2."..ui.R.."  Alterar Idle Time (Ocioso) "..ui.DM.."(padrão: 30s | máx: 180s)"..ui.R.."\n")
    io.write("  "..ui.B.."3."..ui.R.."  Alterar max tentativas     "..ui.DM.."(padrão: 10)"..ui.R.."\n")
    io.write("  "..ui.B.."4."..ui.R.."  Modo retry                 "..ui.DM.."(exponential | static)"..ui.R.."\n")
    io.write("  "..ui.B.."5."..ui.R.."  Restaurar padrões\n")
    io.write("  "..ui.B.."6."..ui.R.."  Modo de Requisicao         "..ui.DM.."(stream | buffer)"..ui.R.."\n")
    io.write("  "..ui.B.."7."..ui.R.."  Alterar wait timeout       "..ui.DM.."(padrao: 25s | buffer)"..ui.R.."\n")
    io.write("  "..ui.B.."8."..ui.R.."  Reasoning Effort (OpenRouter) "..ui.DM.."(6 níveis — só afeta modelos com reasoning_style=openrouter)"..ui.R.."\n")
    io.write("  "..ui.B.."9."..ui.R.."  Thinking Effort (OpenCode Zen) "..ui.DM.."(3 níveis — afeta hy3-free e outros com reasoning_style=reasoning_effort)"..ui.R.."\n")
    io.write("  "..ui.B.."0."..ui.R.."  Voltar\n\n")
    local ch = ui.rdl("Escolha")
    if ui.cancel(ch) then break end

    if ch == "1" then
      local s = ui.rdl("Max Time (Total) em segundos (1 a 300)")
      local v = tonumber(s)
      if v and v >= 1 and v <= 300 then
        config_mod.set("agents.defaults.request.timeout", v)
        io.write(ui.G.."\n  ✅ Max Time: "..v.."s\n"..ui.R)
      else io.write(ui.RE.."\n  ❌ Inválido. O limite é 300s.\n"..ui.R) end
      ui.pause()

    elseif ch == "2" then
      local s = ui.rdl("Idle Time (Ocioso) em segundos (1 a 180)")
      local v = tonumber(s)
      if v and v >= 1 and v <= 180 then
        config_mod.set("agents.defaults.request.idle_timeout", v)
        io.write(ui.G.."\n  ✅ Idle Time: "..v.."s\n"..ui.R)
      else io.write(ui.RE.."\n  ❌ Inválido. O limite é 180s.\n"..ui.R) end
      ui.pause()

    elseif ch == "3" then
      local s = ui.rdl("Número de tentativas (1-20)")
      local v = tonumber(s)
      if v and v >= 1 and v <= 20 then
        config_mod.set("agents.defaults.request.max_retries", v)
        io.write(ui.G.."\n  ✅ Max tentativas: "..v.."\n"..ui.R)
      else io.write(ui.RE.."\n  ❌ Inválido (1-20).\n"..ui.R) end
      ui.pause()

    elseif ch == "4" then
      io.write("  "..ui.B.."1."..ui.R.."  exponential  "..ui.DM.."(1s → 2s → 4s → 8s... até o máximo)"..ui.R.."\n")
      io.write("  "..ui.B.."2."..ui.R.."  static        "..ui.DM.."(mesmo intervalo em todas as tentativas)"..ui.R.."\n\n")
      local mch = ui.rdl("Modo (1/2)")
      if mch == "1" then
        config_mod.set("agents.defaults.request.retry_mode", "exponential")
        local mx = ui.rdl("Tempo máximo em segundos (padrão: 30)")
        local mv = tonumber(mx)
        if mv and mv >= 1 then config_mod.set("agents.defaults.request.retry_max", mv) end
        io.write(ui.G.."\n  ✅ Modo: exponential (máx: "..(mv or rmax).."s)\n"..ui.R)
      elseif mch == "2" then
        config_mod.set("agents.defaults.request.retry_mode", "static")
        local sv = ui.rdl("Intervalo fixo em segundos (ex: 5)")
        local s2 = tonumber(sv)
        if s2 and s2 >= 1 then config_mod.set("agents.defaults.request.retry_static", s2) end
        io.write(ui.G.."\n  ✅ Modo: static (".. (s2 or 5) .."s por tentativa)\n"..ui.R)
      end
      ui.pause()

    elseif ch == "5" then
      config_mod.set("agents.defaults.request.timeout",           180)
      config_mod.set("agents.defaults.request.idle_timeout",       30)
      config_mod.set("agents.defaults.request.max_retries",        10)
      config_mod.set("agents.defaults.request.retry_mode",   "exponential")
      config_mod.set("agents.defaults.request.retry_max",          30)
      config_mod.set("agents.defaults.request.retry_static",        5)
      config_mod.set("agents.defaults.request.mode",          "stream")
      config_mod.set("agents.defaults.request.reasoning_effort", "medium")
      io.write(ui.G.."\n  ✅ Padrões restaurados.\n"..ui.R)
      ui.pause()

    elseif ch == "6" then
      io.write("\n")
      io.write("  "..ui.B.."1."..ui.R.."  stream  "..ui.DM.."(curl direto - tokens em tempo real, padrao)"..ui.R.."\n")
      io.write("  "..ui.B.."2."..ui.R.."  buffer  "..ui.DM.."(wrapper - cancela se servidor nao responde)"..ui.R.."\n\n")
      local mch = ui.rdl("Modo (1/2)")
      if mch == "1" then
        config_mod.set("agents.defaults.request.mode", "stream")
        io.write(ui.G.."\n  Modo: stream\n"..ui.R)
      elseif mch == "2" then
        config_mod.set("agents.defaults.request.mode", "buffer")
        local cur_wt = (ui.get_cfg().agents.defaults.request or {}).wait_timeout or 0
        if cur_wt == 0 then
          config_mod.set("agents.defaults.request.wait_timeout", 25)
          io.write(ui.G.."\n  Modo: buffer\n"..ui.R)
          io.write(ui.YL.."  wait_timeout era 0 - auto-configurado para 25s.\n"..ui.R)
        else
          io.write(ui.G.."\n  Modo: buffer (wait: "..cur_wt.."s)\n"..ui.R)
        end
      else
        io.write(ui.GR.."\n  Cancelado.\n"..ui.R)
      end
      ui.pause()

    elseif ch == "7" then
      local s = ui.rdl("Wait timeout em segundos (5-120, padrao: 25)")
      local v = tonumber(s)
      if v and v >= 5 and v <= 120 then
        config_mod.set("agents.defaults.request.wait_timeout", v)
        io.write(ui.G.."\n  Wait timeout: "..v.."s\n"..ui.R)
      else io.write(ui.RE.."\n  Invalido (5-120s).\n"..ui.R) end
      ui.pause()

    elseif ch == "8" then
      io.write("\n"..ui.GR.."  Reasoning Effort (OpenRouter) — só afeta modelos com reasoning_style=openrouter"..ui.R.."\n")
      io.write("  "..ui.B.."1."..ui.R.."  high\n")
      io.write("  "..ui.B.."2."..ui.R.."  medium\n")
      io.write("  "..ui.B.."3."..ui.R.."  low\n")
      io.write("  "..ui.B.."4."..ui.R.."  xhigh\n")
      io.write("  "..ui.B.."5."..ui.R.."  minimal\n")
      io.write("  "..ui.B.."6."..ui.R.."  none\n")
      io.write("  "..ui.B.."0."..ui.R.."  Cancelar\n\n")
      local lch = ui.rdl("Escolha")
      local efforts = {["1"]="high",["2"]="medium",["3"]="low",["4"]="xhigh",["5"]="minimal",["6"]="none"}
      if efforts[lch] then
        config_mod.set("agents.defaults.request.reasoning_effort", efforts[lch])
        io.write(ui.G.."\n  ✅ Effort: "..efforts[lch].."\n"..ui.R)
      else io.write(ui.GR.."\n  Cancelado.\n"..ui.R) end
      ui.pause()

    elseif ch == "9" then
      -- Valores confirmados na documentação oficial do Hy3 (Tencent): não
      -- existe "xhigh" documentado pra esse modelo — só 3 níveis reais.
      io.write("\n"..ui.GR.."  Thinking Effort (OpenCode Zen) — afeta hy3-free e outros reasoning_effort"..ui.R.."\n")
      io.write("  "..ui.B.."1."..ui.R.."  Non-think   "..ui.DM.."(no_think — respostas rápidas, sem raciocínio)"..ui.R.."\n")
      io.write("  "..ui.B.."2."..ui.R.."  Think       "..ui.DM.."(low — raciocínio leve)"..ui.R.."\n")
      io.write("  "..ui.B.."3."..ui.R.."  Think High  "..ui.DM.."(high — raciocínio profundo, padrão recomendado)"..ui.R.."\n")
      io.write("  "..ui.B.."0."..ui.R.."  Cancelar\n\n")
      local tch = ui.rdl("Escolha")
      local tefforts = {["1"]="no_think",["2"]="low",["3"]="high"}
      if tefforts[tch] then
        config_mod.set("agents.defaults.thinkingEffort", tefforts[tch])
        io.write(ui.G.."\n  ✅ Thinking Effort: "..tefforts[tch].."\n"..ui.R)
      else io.write(ui.GR.."\n  Cancelado.\n"..ui.R) end
      ui.pause()
    end
  end
end

return M
