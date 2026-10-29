-- ui/spinner/retry.lua — Card de retry de API: 2–3 linhas, atualiza no lugar, sem emoji.
-- Reutiliza ui.card.bg_row. Fundo vermelho escuro + texto laranja (contraste).
local core = require("ui.core")
local card = require("ui.card")
local c    = core.c

local M = {}

-- Quantas linhas o card de retry ocupa agora (para ESC[nA + apagar).
local _retry_lines = 0

local function bg_error()
  return c.bg_error or "\27[48;5;52m"
end

local function paint(lines)
  local tw = core.tw()
  local bg = bg_error()
  for i, row in ipairs(lines) do
    local tc = row.dim and c.gray or c.orange
    io.write(card.bg_row(bg, tc, row.prefix or "", tc, row.text or "", tw) .. "\n")
  end
  io.flush()
  return #lines
end

local function erase()
  if _retry_lines > 0 then
    io.write(string.format("\27[%dA\27[J", _retry_lines))
    io.flush()
    _retry_lines = 0
  end
end

--- Atualiza (ou cria) o card de tentativa no mesmo lugar — nunca empilha lista.
-- attempt/max: 1/5 … 5/5. reason: texto curto. wait: segundos (0 = sem linha de espera).
function M.show_retry(attempt, max, reason, wait)
  erase()
  reason = tostring(reason or "erro"):gsub("\n", " ")
  -- Cabe em ~tw-8 colunas; o card corta o resto.
  local tw = core.tw()
  local head = string.format("Tentativa %d/%d — %s", attempt, max, reason)
  local rows = {
    { prefix = " ", text = card.cut(head, math.max(8, tw - 4)) },
  }
  if wait and wait > 0 then
    rows[#rows + 1] = {
      prefix = " ",
      text = card.cut(string.format("Aguardando %ss…", wait), math.max(8, tw - 4)),
      dim = true,
    }
  end
  _retry_lines = paint(rows)
end

--- Card final de erro (substitui o de retry). Não entra em _retry_lines
-- (não deve ser apagado por clear_retry_lines / stream_confirm).
function M.show_api_error(msg)
  erase()
  msg = tostring(msg or "Erro de API"):gsub("\n", " ")
  local tw = core.tw()
  local rows = {
    { prefix = " ", text = card.cut("[ERRO] " .. msg, math.max(8, tw - 4)) },
  }
  paint(rows)
  -- permanente: não rastrear em _retry_lines
  _retry_lines = 0
end

function M.clear_retry_lines()
  erase()
end

return M
