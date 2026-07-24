local M = {}

M.OPEN_TOOL  = "<tool>"
M.CLOSE_TOOL = "</tool>"

M.OPEN_THINKING  = { "<think>", "<thought>" }
M.MATCHING_CLOSE = {
  ["<think>"]   = "</think>",
  ["<thought>"] = "</thought>",
}

return M
