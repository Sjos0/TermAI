-- ui/misc.lua — mensagens auxiliares e rodapé em Block (#250).
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

local function token_color(pct)
  if pct < 50  then return "\27[38;5;245m" end
  if pct < 65  then return "\27[38;5;229m" end
  if pct < 80  then return "\27[38;5;222m" end
  if pct < 90  then return "\27[38;5;220m" end
  if pct < 95  then return "\27[38;5;208m" end
  if pct < 100 then return "\27[38;5;202m" end
  return "\27[38;5;196m"
end

--- Rodapé: 3 linhas Block PLAIN branco; tw < 20 → linha simples.
--- Assinatura inalterada: footer(tokens, limit, elapsed_ms, end_time).
function M.footer(a, b, elapsed_ms, end_time)
  local formatar = require("ui.format_num").formatar_limite
  local pct = (b and b > 0) and (a / b * 100) or 0
  local tok = token_color(pct)
    .. ("tokens: %s/%s (%.1f%%)"):format(
      formatar(a), formatar(b), pct) .. c.reset
  local tseg = elapsed_ms and timing.format_duration(elapsed_ms) or nil
  local clock = end_time or nil

  local tw = core.tw()
  if tw < 20 then
    local line = tok
    if tseg then line = line .. " | " .. tseg end
    if clock then line = line .. " | " .. clock end
    io.write(line .. "\n\n")
    return
  end

  local segs = { tok }
  if tseg then segs[#segs + 1] = tseg end
  if clock then segs[#segs + 1] = clock end

  local block = require("ui.widgets.block")
  local layout = require("ui.widgets.layout")
  local inner_w = math.max(0, tw - 2)
  local widths = layout.split_equal(inner_w, #segs)
  local content = layout.place(segs, widths, inner_w)

  local bobj = block.new({
    borders = block.BORDERS.ALL,
    border_type = block.TYPE.PLAIN,
    border_color = c.white or "\27[37m",
    content_lines = { content },
  })
  local lines = bobj:render({ w = tw, h = 3 })
  for _, ln in ipairs(lines) do
    io.write(ln .. "\n")
  end
  io.write("\n") -- linha em branco DEPOIS do Block
end

function M.loading(t)
  io.write("\r" .. c.gray .. t .. c.clear .. c.reset); io.flush()
end

function M.clear_loading()
  io.write("\r\27[K"); io.flush()
end

return M
