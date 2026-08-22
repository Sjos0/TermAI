-- commands/config/menus/request/actions.lua — Camada controladora (Controller) de ações do menu.
local ui         = require("commands.models.ui")
local api        = require("agent.api")
local saver      = require("commands.config.menus.request.saver")
local c = ui.c

local M = {}

function M.change_timeout(ctx)
  local s = ui.prompt_read("Timeout em segundos (0 = sem limite)")
  local v = tonumber(s)
  if v and v >= 0 then
    local t = (v == 0) and 999999 or v
    saver.save_req(ctx, "timeout", t)
    api.CURL_TIMEOUT = t
    io.write(c.green.."\n  ✅ Timeout: "..(v==0 and "sem limite" or (v.."s")).."\n"..c.reset)
  else 
    io.write(c.red.."\n  ❌ Inválido.\n"..c.reset) 
  end
  ui.pause()
end

function M.change_max_retries(ctx)
  local s = ui.prompt_read("Número máximo de tentativas (1-20)")
  local v = tonumber(s)
  if v and v >= 1 and v <= 20 then
    saver.save_req(ctx, "max_retries", v)
    api.MAX_RETRIES = v
    io.write(c.green.."\n  ✅ Max tentativas: "..v.."\n"..c.reset)
  else 
    io.write(c.red.."\n  ❌ Inválido (1-20).\n"..c.reset) 
  end
  ui.pause()
end

function M.change_retry_mode(ctx)
  io.write("  "..c.white.."1."..c.reset.."  exponential  "..c.dim.."(1s, 2s, 4s, 8s... dobra até o máximo)"..c.reset.."\n")
  io.write("  "..c.white.."2."..c.reset.."  static        "..c.dim.."(mesmo intervalo em toda tentativa)"..c.reset.."\n\n")
  local mch = ui.prompt_read("Escolha modo")
  if mch == "1" then
    saver.save_req(ctx, "retry_mode", "exponential")
    api.RETRY_MODE = "exponential"
    local mx = ui.prompt_read("Tempo máximo de espera em segundos (padrão: 30)")
    local mv = tonumber(mx)
    if mv and mv >= 1 then
      saver.save_req(ctx, "retry_max", mv)
      api.RETRY_MAX = mv
    end
    io.write(c.green.."\n  ✅ Modo: exponential\n"..c.reset)
  elseif mch == "2" then
    saver.save_req(ctx, "retry_mode", "static")
    api.RETRY_MODE = "static"
    local sv = ui.prompt_read("Intervalo fixo em segundos (ex: 5)")
    local s2 = tonumber(sv)
    if s2 and s2 >= 1 then
      saver.save_req(ctx, "retry_static", s2)
      api.RETRY_STATIC = s2
    end
    io.write(c.green.."\n  ✅ Modo: static  (".. (tonumber(sv) or 5) .."s)\n"..c.reset)
  end
  ui.pause()
end

function M.restore_defaults(ctx)
  saver.save_req(ctx, "timeout", 120)
  saver.save_req(ctx, "max_retries", 10)
  saver.save_req(ctx, "retry_mode", "exponential")
  saver.save_req(ctx, "retry_max", 30)
  saver.save_req(ctx, "mode", "stream")
  saver.save_req(ctx, "reasoning_effort", "medium")
  api.CURL_TIMEOUT = 120
  api.MAX_RETRIES  = 10
  api.RETRY_MODE   = "exponential"
  api.RETRY_MAX    = 30
  io.write(c.green.."\n  ✅ Padrões restaurados.\n"..c.reset)
  ui.pause()
end

function M.change_wait_timeout(ctx)
  local s = ui.prompt_read("Wait timeout em segundos (cancela se servidor nao responde, 5-120)")
  local v = tonumber(s)
  if v and v >= 5 and v <= 120 then
    saver.save_req(ctx, "wait_timeout", v)
    io.write(c.green.."\n  ✅ Wait timeout: "..v.."s\n"..c.reset)
  else 
    io.write(c.red.."\n  ❌ Invalido (5-120s).\n"..c.reset) 
  end
  ui.pause()
end

function M.change_request_mode(ctx)
  io.write("\n")
  io.write("  "..c.white.."1."..c.reset.."  stream  "..c.dim.."(curl direto - tokens em tempo real, padrao)"..c.reset.."\n")
  io.write("  "..c.white.."2."..c.reset.."  buffer  "..c.dim.."(wrapper - cancela se servidor nao responde)"..c.reset.."\n\n")
  local mch = ui.prompt_read("Modo (1/2)")
  if mch == "1" then
    saver.save_req(ctx, "mode", "stream")
    io.write(c.green.."\n  Modo: stream\n"..c.reset)
  elseif mch == "2" then
    saver.save_req(ctx, "mode", "buffer")
    local cur_wt = (ctx.cfg.agents.defaults.request or {}).wait_timeout or 0
    if cur_wt == 0 then
      saver.save_req(ctx, "wait_timeout", 25)
      io.write(c.green.."\n  Modo: buffer\n"..c.reset)
      io.write(c.yellow.."  wait_timeout era 0 - auto-configurado para 25s.\n"..c.reset)
    else
      io.write(c.green.."\n  Modo: buffer (wait: "..cur_wt.."s)\n"..c.reset)
    end
  else
    io.write(c.gray.."\n  Cancelado.\n"..c.reset)
  end
  ui.pause()
end

function M.change_reasoning_effort(ctx)
  io.write("\n"..c.gray.."  Reasoning Effort (OpenRouter) — só afeta modelos com reasoning_style=openrouter"..c.reset.."\n")
  io.write("  "..c.white.."1."..c.reset.."  high     "..c.dim.."(Profundo)"..c.reset.."\n")
  io.write("  "..c.white.."2."..c.reset.."  medium   "..c.dim.."(Equilibrado - Padrão)"..c.reset.."\n")
  io.write("  "..c.white.."3."..c.reset.."  low      "..c.dim.."(Leve)"..c.reset.."\n")
  io.write("  "..c.white.."4."..c.reset.."  xhigh    "..c.dim.."(Máximo)"..c.reset.."\n")
  io.write("  "..c.white.."5."..c.reset.."  minimal  "..c.dim.."(Básico)"..c.reset.."\n")
  io.write("  "..c.white.."6."..c.reset.."  none     "..c.dim.."(Desativado)"..c.reset.."\n")
  io.write("  "..c.white.."0."..c.reset.."  Cancelar\n\n")
  local lch = ui.prompt_read("Escolha")
  local efforts = {["1"]="high",["2"]="medium",["3"]="low",["4"]="xhigh",["5"]="minimal",["6"]="none"}
  if efforts[lch] then
    saver.save_req(ctx, "reasoning_effort", efforts[lch])
    io.write(c.green.."\n  ✅ Effort: "..efforts[lch].."\n"..c.reset)
  else 
    io.write(c.gray.."\n  Cancelado.\n"..c.reset) 
  end
  ui.pause()
end

function M.change_language(ctx)
  io.write("\27[2J\27[H") -- Clear screen
  io.flush()
  local SEP = string.rep("─", 45)
  io.write("\n"..c.bold..c.cyan.."  Configurações › Idioma do Agente"..c.reset.."\n")
  io.write(c.gray.."  "..SEP..c.reset.."\n\n")
  io.write("  "..c.white.."1."..c.reset.."  Portuguese (Português - Padrão)\n")
  io.write("  "..c.white.."2."..c.reset.."  English (Inglês)\n")
  io.write("  "..c.white.."3."..c.reset.."  Spanish (Español)\n")
  io.write("  "..c.white.."0."..c.reset.."  Cancelar\n\n")
  local lch = ui.prompt_read("Escolha")
  local langs = {["1"]="Portuguese", ["2"]="English", ["3"]="Spanish"}
  if langs[lch] then
    saver.save_req(ctx, "language", langs[lch])
    io.write(c.green.."\n  ✅ Idioma do Agente configurado para: "..langs[lch].."\n"..c.reset)
  else 
    io.write(c.gray.."\n  Cancelado.\n"..c.reset) 
  end
  ui.pause()
end

function M.change_thinking_effort(ctx)
  -- Valores confirmados na documentação oficial do Hy3 (Tencent): não
  -- existe "xhigh" documentado pra esse modelo — só 3 níveis reais.
  io.write("\n"..c.gray.."  Thinking Effort (OpenCode Zen) — afeta hy3-free e outros reasoning_effort"..c.reset.."\n")
  io.write("  "..c.white.."1."..c.reset.."  Non-think   "..c.dim.."(no_think — respostas rápidas, sem raciocínio)"..c.reset.."\n")
  io.write("  "..c.white.."2."..c.reset.."  Think       "..c.dim.."(low — raciocínio leve)"..c.reset.."\n")
  io.write("  "..c.white.."3."..c.reset.."  Think High  "..c.dim.."(high — raciocínio profundo, padrão recomendado)"..c.reset.."\n")
  io.write("  "..c.white.."0."..c.reset.."  Cancelar\n\n")
  local tch = ui.prompt_read("Escolha")
  local tefforts = {["1"]="no_think",["2"]="low",["3"]="high"}
  if tefforts[tch] then
    saver.save_defaults(ctx, "thinkingEffort", tefforts[tch])
    io.write(c.green.."\n  ✅ Thinking Effort: "..tefforts[tch].."\n"..c.reset)
  else
    io.write(c.gray.."\n  Cancelado.\n"..c.reset)
  end
  ui.pause()
end

return M
