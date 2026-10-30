-- ui/spinner/retry.lua — Blocos de tentativa e erro via Block (#203, #268, #270).
local core  = require("ui.core")
local block = require("ui.widgets.block")
local c     = core.c

local M = {}
local _retry_lines = 0
local _active = false

local RED   = c.red or "\27[38;5;203m"
local BG    = c.bg_error or "\27[48;5;52m"
local WHITE = "\27[38;5;255m"

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
    border_color = RED,
    bg = BG,
    fg = WHITE,
    content_lines = content_lines,
  })
  local lines = b:render({ w = tw, h = nil })
  for _, ln in ipairs(lines) do
    io.write(ln .. "\n")
  end
  io.flush()
  return #lines
end

function M.is_active()
  return _active
end

--- Uma linha: "Tentativa N/M — motivo · aguardando Xs" (corta motivo se preciso).
function M.show_retry(attempt, max, reason, wait)
  erase()
  reason = tostring(reason or "erro"):gsub("\n", " ")
  local head = string.format("Tentativa %d/%d — %s", attempt, max, reason)
  if wait and wait > 0 then
    head = head .. string.format(" · aguardando %ss", wait)
  end
  -- Block wrap já corta por palavra; para tentativa forçamos 1 linha de conteúdo
  -- mantendo prefixo Tentativa N/M visível via cortar no meio do motivo se preciso.
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

--- Bloco de erro final: opcional recover_line + [ERRO] mensagem completa (quebra).
function M.show_api_error(msg, recover_line)
  erase()
  msg = tostring(msg or "Erro de API")
  local content = {}
  if recover_line and tostring(recover_line) ~= "" then
    content[#content + 1] = tostring(recover_line)
  end
  content[#content + 1] = "[ERRO] " .. msg
  -- altura cresce; se >40 linhas o Block já limita pelo h fixo — aqui usamos nil
  local lines_count = paint_block(content)
  -- se explodir demais, ainda registramos (limite visual opcional futuro)
  _retry_lines = 0
  _active = false
  return lines_count
end

function M.clear_retry_lines()
  erase()
  _active = false
end

return M
