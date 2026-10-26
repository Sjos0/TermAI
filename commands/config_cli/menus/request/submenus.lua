-- commands/config_cli/menus/request/submenus.lua — submenus do menu de requisições (ramos 4 a 9).
local M = {}

function M.modo_retry(config_mod, ui, rmax)
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
end

function M.restaurar(config_mod, ui)
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
end

function M.modo_requisicao(config_mod, ui)
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
end

function M.wait_timeout(config_mod, ui)
  local s = ui.rdl("Wait timeout em segundos (5-120, padrao: 25)")
  local v = tonumber(s)
  if v and v >= 5 and v <= 120 then
    config_mod.set("agents.defaults.request.wait_timeout", v)
    io.write(ui.G.."\n  Wait timeout: "..v.."s\n"..ui.R)
  else io.write(ui.RE.."\n  Invalido (5-120s).\n"..ui.R) end
  ui.pause()
end

function M.reasoning_effort(config_mod, ui)
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
end

function M.thinking_effort(config_mod, ui)
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

return M
