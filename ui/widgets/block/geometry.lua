-- ui/widgets/block/geometry.lua — inner(area) com padding e saturating_sub.
local borders = require("ui.widgets.block.borders")

local M = {}

local function sat_sub(a, b)
  if a <= b then return 0 end
  return a - b
end

function M.inner(area, opts)
  opts = opts or {}
  local flags = opts.borders or borders.ALL
  local pad = opts.padding or {}
  local pl = pad.left or 0
  local pr = pad.right or 0
  local pt = pad.top or 0
  local pb = pad.bottom or 0

  local top = borders.has(flags, borders.TOP) and 1 or 0
  local bottom = borders.has(flags, borders.BOTTOM) and 1 or 0
  local left = borders.has(flags, borders.LEFT) and 1 or 0
  local right = borders.has(flags, borders.RIGHT) and 1 or 0

  local x = (area.x or 1) + left + pl
  local y = (area.y or 1) + top + pt
  local w = sat_sub(area.w or 0, left + right + pl + pr)
  local h = sat_sub(area.h or 0, top + bottom + pt + pb)
  return { x = x, y = y, w = w, h = h }
end

return M
