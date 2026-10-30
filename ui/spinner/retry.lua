-- ui/spinner/retry.lua — Card de retry in-place; conta linhas físicas (#203, #268).
local core = require("ui.core")
local card = require("ui.card")
local c    = core.c

local M = {}
local _retry_lines = 0
local _active = false

local function bg_error()
  return c.bg_error or "\27[48;5;52m"
end

-- Cada row já cortada cabe em 1 linha física (cortar garante colunas <= tw-1).
local function paint(rows)
  local tw = core.tw()
  local bg = bg_error()
  local physical = 0
  for _, row in ipairs(rows) do
    local tc = row.dim and c.gray or c.orange
    io.write(card.bg_row(bg, tc, row.prefix or "", tc, row.text or "", tw) .. "\n")
    physical = physical + 1
  end
  io.flush()
  return physical
end

local function erase()
  if _retry_lines > 0 then
    io.write(string.format("\27[%dA\27[J", _retry_lines))
    io.flush()
    _retry_lines = 0
  end
end

--- true enquanto um card de tentativa está na tela (antes de show_api_error/clear).
function M.is_active()
  return _active
end

function M.show_retry(attempt, max, reason, wait)
  erase()
  reason = tostring(reason or "erro"):gsub("\n", " ")
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
  _active = true
end

function M.show_api_error(msg)
  erase()
  msg = tostring(msg or "Erro de API"):gsub("\n", " ")
  local tw = core.tw()
  local rows = {
    { prefix = " ", text = card.cut("[ERRO] " .. msg, math.max(8, tw - 4)) },
  }
  paint(rows)
  _retry_lines = 0 -- permanente
  _active = false
end

function M.clear_retry_lines()
  erase()
  _active = false
end

return M
