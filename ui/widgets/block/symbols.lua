-- ui/widgets/block/symbols.lua — conjuntos de borda (Ratatui BorderType).
local M = {}

M.PLAIN = {
  top_left = "┌", top_right = "┐",
  bottom_left = "└", bottom_right = "┘",
  horizontal = "─", vertical = "│",
}

M.ROUNDED = {
  top_left = "╭", top_right = "╮",
  bottom_left = "╰", bottom_right = "╯",
  horizontal = "─", vertical = "│",
}

M.DOUBLE = {
  top_left = "╔", top_right = "╗",
  bottom_left = "╚", bottom_right = "╝",
  horizontal = "═", vertical = "║",
}

M.THICK = {
  top_left = "┏", top_right = "┓",
  bottom_left = "┗", bottom_right = "┛",
  horizontal = "━", vertical = "┃",
}

return M
