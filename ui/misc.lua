-- ui/misc.lua — mensagens auxiliares e rodapé em Block (#250/#265/#277).
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

--- Política de corte (#277): (a) pct curto (b) sem pct (c) sem tempo (d) relógio por último.
local function build_segments(a, b, elapsed_ms, end_time, inner_w)
  local formatar = require("ui.format_num").formatar_limite
  local largura = require("ui.largura")
  local layout = require("ui.widgets.layout")
  local pct = (b and b > 0) and (a / b * 100) or 0
  local tseg = elapsed_ms and timing.format_duration(elapsed_ms) or nil
  local clock = end_time or nil

  local function tok_sgr(plain)
    return token_color(pct) .. plain .. c.reset
  end

  local forms = {
    tok_sgr(("Tokens: %s/%s (%.1f%%)"):format(formatar(a), formatar(b), pct)),
    tok_sgr(("Tokens: %s/%s (%.0f%%)"):format(formatar(a), formatar(b), pct)), -- (a) pct curto
    tok_sgr(("Tokens: %s/%s"):format(formatar(a), formatar(b))),               -- (b) sem pct
  }

  local candidates = {}
  for _, tok in ipairs(forms) do
    if tseg and clock then candidates[#candidates+1] = { tok, tseg, clock } end
    if tseg then candidates[#candidates+1] = { tok, tseg } end
    if clock then candidates[#candidates+1] = { tok, clock } end
    candidates[#candidates+1] = { tok }
  end

  for _, segs in ipairs(candidates) do
    local line = layout.place_natural(segs, inner_w)
    if line then return segs, line end
  end
  -- último recurso: só tokens cortados
  local plain = largura.cortar(("Tokens: %s/%s"):format(formatar(a), formatar(b)), inner_w)
  local tok = tok_sgr(plain)
  return { tok }, layout.place_natural({ tok }, inner_w) or (tok .. string.rep(" ", math.max(0, inner_w - largura.colunas(tok))))
end

function M.footer(a, b, elapsed_ms, end_time)
  local formatar = require("ui.format_num").formatar_limite
  local pct = (b and b > 0) and (a / b * 100) or 0
  local tw = core.tw()

  if tw < 20 then
    local tok = token_color(pct)
      .. ("Tokens: %s/%s (%.1f%%)"):format(formatar(a), formatar(b), pct) .. c.reset
    local line = tok
    if elapsed_ms then line = line .. " | " .. timing.format_duration(elapsed_ms) end
    if end_time then line = line .. " | " .. end_time end
    io.write(line .. "\n\n")
    return
  end

  local block = require("ui.widgets.block")
  local layout = require("ui.widgets.layout")
  local largura = require("ui.largura")
  local inner_w = math.max(0, tw - 2)
  local segs, content = build_segments(a, b, elapsed_ms, end_time, inner_w)
  if not content then
    content = layout.place_natural(segs, inner_w) or table.concat(segs, " ")
  end

  local bobj = block.new({
    borders = block.BORDERS.ALL,
    border_type = block.TYPE.PLAIN,
    border_color = c.white or "\27[37m",
    content_lines = { content },
  })
  local lines = bobj:render({ w = tw, h = 3 })
  for _, ln in ipairs(lines) do io.write(ln .. "\n") end
  io.write("\n")
end

function M.loading(t)
  io.write("\r" .. c.gray .. t .. c.clear .. c.reset); io.flush()
end

function M.clear_loading()
  io.write("\r\27[K"); io.flush()
end

return M
