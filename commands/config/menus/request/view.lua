-- commands/config/menus/request/view.lua — Camada de visualização (View) do menu de requisições.
local ui = require("commands.models.ui")
local api = require("agent.api")
local c = ui.c

local M = {}

local core = require("ui.core")
local largura = require("ui.largura")
-- Réguas responsivas (#331): função, não valor — core.tw() é lido a cada uso,
-- então girar o celular já muda o separador. `prefixo`/`usado` é o que já
-- ocupou a linha; a régua encolhe o quanto precisar para não estourar tw.
local function SEP(usado)    return core.regua(45, usado or 2) end
local function SEP2(prefixo) return core.regua(30, require("ui.largura").colunas(prefixo or "")) end

local function row(label, value, color)
  color = color or c.white
  local limite = math.max(12, core.tw() - 4)
  local prefixo = "  " .. tostring(label) .. " "
  local texto = color .. tostring(value) .. c.reset
  local disponivel = limite - largura.colunas(prefixo)
  if disponivel >= 8 then
    local linhas = largura.quebrar(texto, disponivel)
    io.write(c.gray .. prefixo .. c.reset .. (linhas[1] or "") .. "\n")
    for i = 2, #linhas do
      io.write(string.rep(" ", largura.colunas(prefixo)) .. linhas[i] .. "\n")
    end
    return
  end

  local rotulo = largura.quebrar(tostring(label), math.max(1, limite - 2))
  for _, linha in ipairs(rotulo) do
    io.write(c.gray .. "  " .. linha .. c.reset .. "\n")
  end
  local linhas = largura.quebrar(texto, math.max(8, limite - 4))
  for _, linha in ipairs(linhas) do io.write("    " .. linha .. "\n") end
end

local function option(number, title, description)
  local prefixo = "  " .. tostring(number) .. ". "
  local limite = math.max(12, core.tw() - 4)
  local linhas = largura.quebrar(title, math.max(8, limite - largura.colunas(prefixo)))
  io.write(prefixo .. (linhas[1] or "") .. "\n")
  for i = 2, #linhas do io.write("     " .. linhas[i] .. "\n") end
  if not description or description == "" then return end
  local descricao = largura.quebrar(description, math.max(8, limite - 6))
  for _, linha in ipairs(descricao) do
    io.write("      " .. c.dim .. linha .. c.reset .. "\n")
  end
end

function M.print_header()
  io.write("\27[2J\27[H") -- Limpa a tela
  io.flush()
  io.write("\n"..c.bold..c.cyan.."  Configurações › Requisições"..c.reset.."\n")
  io.write(c.gray.."  "..SEP()..c.reset.."\n\n")
end

function M.print_status(req, defaults)
  local tout    = req.timeout      or api.CURL_TIMEOUT
  local retries = req.max_retries  or api.MAX_RETRIES
  local mode    = req.retry_mode   or api.RETRY_MODE
  local static  = req.retry_static or api.RETRY_STATIC
  local rmax    = req.retry_max    or api.RETRY_MAX
  local wt      = req.wait_timeout or 0
  local req_mode = req.mode or ((wt > 0) and "buffer" or "stream")

  io.write(c.gray.."  ── Status atual "..SEP2("  ── Status atual ")..c.reset.."\n")
  
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
  
  row("Reasoning Effort (OpenRouter):", req.reasoning_effort or "medium", c.cyan)
  row("Thinking Effort (OpenCode Zen):", (defaults.thinkingEffort or "high"), c.cyan)
  row("Idioma do Agente:", req.language or "Portuguese", c.cyan)
end

function M.print_options()
  io.write("\n"..c.gray.."  ── Opções "..SEP2("  ── Opções ")..c.reset.."\n")
  option("1", "Alterar timeout", "(padrão: 120s)")
  option("2", "Alterar max tentativas", "(padrão: 10)")
  option("3", "Modo retry", "(exponential / static)")
  option("4", "Restaurar padrões")
  option("5", "Alterar wait timeout", "(padrão: 25s)")
  option("6", "Modo de Requisicao", "(stream / buffer)")
  option("7", "Reasoning Effort (OpenRouter)", "(6 níveis — só afeta modelos com reasoning_style=openrouter)")
  option("8", "Idioma do Agente", "(Português / English / Español)")
  option("9", "Thinking Effort (OpenCode Zen)", "(3 níveis — afeta hy3-free e outros com reasoning_style=reasoning_effort)")
  option("10", "Fallback (API Keys, modelos e transparência)")
  option("0", "Voltar")
  io.write("\n")
end

return M
