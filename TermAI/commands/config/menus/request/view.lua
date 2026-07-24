-- commands/config/menus/request/view.lua — Camada de visualização (View) do menu de requisições.
local ui = require("commands.models.ui")
local api = require("agent.api")
local c = ui.c

local M = {}

local SEP  = string.rep("─", 45)
local SEP2 = string.rep("─", 30)

local function row(label, value, color)
  color = color or c.white
  io.write(string.format("  %s%-22s%s %s%s%s\n",
    c.gray, label, c.reset, color, tostring(value), c.reset))
end

function M.print_header()
  io.write("\27[2J\27[H") -- Limpa a tela
  io.flush()
  io.write("\n"..c.bold..c.cyan.."  Configurações › Requisições"..c.reset.."\n")
  io.write(c.gray.."  "..SEP..c.reset.."\n\n")
end

function M.print_status(req)
  local tout    = req.timeout      or api.CURL_TIMEOUT
  local retries = req.max_retries  or api.MAX_RETRIES
  local mode    = req.retry_mode   or api.RETRY_MODE
  local static  = req.retry_static or api.RETRY_STATIC
  local rmax    = req.retry_max    or api.RETRY_MAX
  local wt      = req.wait_timeout or 0
  local req_mode = req.mode or ((wt > 0) and "buffer" or "stream")

  io.write(c.gray.."  ── Status atual "..SEP2..c.reset.."\n")
  
  row("Modo:",
    req_mode == "buffer"
      and (c.yellow.."buffer"..c.reset..c.dim.."  (wrapper - resiliente a rede)"..c.reset)
      or  (c.green .."stream"..c.reset..c.dim.."  (curl direto - tokens em tempo real)"..c.reset))
  
  row("Timeout:",       tout .. "s")
  row("Wait timeout:",
    wt > 0
      and (wt .. "s  "..c.dim.."(cancela se servidor nao responde)"..c.reset)
      or  (c.dim.."desativado"..c.reset))
  
  row("Max tentativas:", tostring(retries))
  row("Modo retry:",    mode)
  
  if mode == "static" then
    row("Wait estático:", static .. "s")
  else
    row("Wait máximo:",  rmax .. "s  (dobra a cada erro)")
  end
  
  row("Reasoning Effort:", req.reasoning_effort or "medium", c.cyan)
  row("Idioma do Agente:", req.language or "Portuguese", c.cyan)
end

function M.print_options()
  io.write("\n"..c.gray.."  ── Opções "..SEP2..c.reset.."\n")
  io.write("  "..c.white.."1."..c.reset.."  Alterar timeout  "..c.dim.."(padrão: 120s)"..c.reset.."\n")
  io.write("  "..c.white.."2."..c.reset.."  Alterar max tentativas  "..c.dim.."(padrão: 10)"..c.reset.."\n")
  io.write("  "..c.white.."3."..c.reset.."  Modo retry  "..c.dim.."(exponential / static)"..c.reset.."\n")
  io.write("  "..c.white.."4."..c.reset.."  Restaurar padrões\n")
  io.write("  "..c.white.."5."..c.reset.."  Alterar wait timeout  "..c.dim.."(padrão: 25s)"..c.reset.."\n")
  io.write("  "..c.white.."6."..c.reset.."  Modo de Requisicao    "..c.dim.."(stream / buffer)"..c.reset.."\n")
  io.write("  "..c.white.."7."..c.reset.."  Reasoning Effort      "..c.dim.."(OpenRouter effort)"..c.reset.."\n")
  io.write("  "..c.white.."8."..c.reset.."  Idioma do Agente      "..c.dim.."(Português / English / Español)"..c.reset.."\n")
  io.write("  "..c.white.."0."..c.reset.."  Voltar\n\n")
end

return M
