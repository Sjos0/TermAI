local core   = require("ui.core")
local timing = require("ui.spinner.timing")
local c = core.c
local M = {}

function M.agent_limit(n)
  io.write(c.yellow .. " ⚠ limite de " .. n .. " iterações atingido\n" .. c.reset)
end

function M.divider()
  io.write(c.gray .. string.rep("─", core.tw()) .. c.reset .. "\n")
end

-- Gradiente do footer de tokens: cinza <50%, amarelo crescente 50-89%,
-- vermelho crescente 90%+ (alinhado ao gatilho padrão de compactação
-- em 90%). Ajustar faixas aqui se compactacao_pct mudar.
local function token_color(pct)
  if pct < 50  then return "\27[38;5;245m" end
  if pct < 65  then return "\27[38;5;229m" end
  if pct < 80  then return "\27[38;5;222m" end
  if pct < 90  then return "\27[38;5;220m" end
  if pct < 95  then return "\27[38;5;208m" end
  if pct < 100 then return "\27[38;5;202m" end
  return "\27[38;5;196m"
end

-- end_time: HH:MM capturado no momento exato em que o stream terminou.
-- Substitui "gw: connected" para mostrar QUANDO a resposta chegou.
-- elapsed agora chega em MILISSEGUNDOS (era segundos inteiros antes).
function M.footer(a, b, elapsed_ms, end_time)
  local t   = elapsed_ms and string.format(" | %s", timing.format_duration(elapsed_ms)) or ""
  local ts  = end_time   and string.format(" | %s", end_time) or ""
  local pct = a / b * 100
  io.write(token_color(pct)
    .. ("tokens: %d/%d (%.1f%%)"):format(a, b, pct)
    .. t .. ts .. c.reset .. "\n\n")
end

function M.loading(t)
  io.write("\r" .. c.gray .. t .. c.clear .. c.reset); io.flush()
end

function M.clear_loading()
  io.write("\r\27[K"); io.flush()
end

return M
