-- ui/widgets/block/borders.lua — flags combináveis de borda.
local M = {}

M.NONE   = 0
M.TOP    = 1
M.RIGHT  = 2
M.BOTTOM = 4
M.LEFT   = 8
M.ALL    = M.TOP + M.RIGHT + M.BOTTOM + M.LEFT

function M.has(flags, side)
  return (flags % (side * 2)) >= side
end

return M
