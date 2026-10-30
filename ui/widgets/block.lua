-- ui/widgets/block.lua — fachada Block (contêiner decorativo, #248/#269).
local borders  = require("ui.widgets.block.borders")
local symbols  = require("ui.widgets.block.symbols")
local geometry = require("ui.widgets.block.geometry")
local render   = require("ui.widgets.block.render")

local M = {}

M.BORDERS = borders
M.TYPE = {
  PLAIN = "PLAIN",
  ROUNDED = "ROUNDED",
  DOUBLE = "DOUBLE",
  THICK = "THICK",
}

function M.new(opts)
  opts = opts or {}
  local self = {
    borders = opts.borders or borders.ALL,
    border_type = opts.border_type or M.TYPE.PLAIN,
    border_color = opts.border_color or "",
    bg = opts.bg or "",
    fg = opts.fg or "",
    padding = opts.padding or { left = 0, right = 0, top = 0, bottom = 0 },
    title = opts.title,
    content_lines = opts.content_lines or {},
  }
  function self:inner(area)
    return geometry.inner(area, {
      borders = self.borders,
      padding = self.padding,
    })
  end
  function self:render(area)
    return render.lines(area, {
      borders = self.borders,
      border_type = self.border_type,
      border_color = self.border_color,
      bg = self.bg,
      fg = self.fg,
      title = self.title,
      content_lines = self.content_lines,
    })
  end
  function self:set_content(lines)
    self.content_lines = lines or {}
  end
  return self
end

return M
