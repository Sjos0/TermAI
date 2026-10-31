-- ui/spinner/retry.lua — Blocos de tentativa e erro via Block (#203–#278).
local core  = require("ui.core")
local block = require("ui.widgets.block")
local c     = core.c

local M = {}
local _retry_lines = 0
local _active = false

local function erase()
  if _retry_lines > 0 then
    io.write(string.format("\27[%dA\27[J", _retry_lines))
    io.flush()
    _retry_lines = 0
  end
end

local function paint_block(content_lines)
  local tw = core.tw()
  local b = block.new({
    borders = block.BORDERS.ALL,
    border_type = block.TYPE.PLAIN,
    border_color = c.frame_error_fg or c.red,
    frame_bg = c.frame_error or "\27[48;5;203m",
    frame_fg = c.frame_error_fg or "\27[38;5;52m",
    bg = c.bg_error or "\27[48;5;52m",
    fg = c.error_fg or "\27[38;5;231m",
    content_lines = content_lines,
  })
  local lines = b:render({ w = tw, h = nil })
  for _, ln in ipairs(lines) do io.write(ln .. "\n") end
  io.flush()
  return #lines
end

function M.is_active()
  return _active
end

function M.show_retry(attempt, max, reason, wait)
  erase()
  reason = tostring(reason or "erro"):gsub("\n", " ")
  local head = string.format("Tentativa %d/%d — %s", attempt, max, reason)
  if wait and wait > 0 then
    head = head .. string.format(" · aguardando %ss", wait)
  end
  local tw = core.tw()
  local inner = math.max(8, tw - 2)
  local largura = require("ui.largura")
  if largura.colunas(head) > inner then
    local prefix = string.format("Tentativa %d/%d — ", attempt, max)
    local suffix = (wait and wait > 0) and string.format(" · aguardando %ss", wait) or ""
    local budget = inner - largura.colunas(prefix) - largura.colunas(suffix) - 1
    if budget < 4 then budget = 4 end
    reason = largura.cortar(reason, budget)
    head = prefix .. reason .. suffix
  end
  _retry_lines = paint_block({ head })
  _active = true
end

function M.show_api_error(msg, recover_line)
  erase()
  msg = tostring(msg or "Erro de API")
  local content = {}
  if recover_line and tostring(recover_line) ~= "" then
    content[#content + 1] = tostring(recover_line)
  end
  content[#content + 1] = "[ERRO] " .. msg
  paint_block(content)
  _retry_lines = 0
  _active = false
end

function M.clear_retry_lines()
  erase()
  _active = false
end

return M
