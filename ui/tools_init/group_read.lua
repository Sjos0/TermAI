-- ui/tools_init/group_read.lua — Leituras agrupadas: "⬤ Read ~ N Arquivos".
local core = require("ui.core")
local c    = core.c
local M    = {}

local DARK_GRAY = "\27[38;5;240m"

function M.tool_group_read_start(count)
  io.write(c.yellow .. "⬤ " .. c.reset .. c.bold .. c.white
    .. "Read ~ " .. count .. " Arquivos" .. c.reset .. "\n")
  io.flush()
end

-- Corpo compartilhado entre tool_group_read_end (live) e _replay (histórico).
local function render_group_read_body(names, oks)
  local any_fail = false
  for _, v in ipairs(oks) do if not v then any_fail = true end end
  local tw = core.tw()
  io.write((any_fail and c.red or c.green) .. "⬤ " .. c.reset .. c.bold .. c.white
    .. "Read ~ " .. #names .. " Arquivos" .. c.reset .. "\n")
  for i, name in ipairs(names) do
    local prefix = (i == #names) and " └─ " or " │ "
    io.write(c.gray .. prefix .. DARK_GRAY .. name:sub(1, tw - 8) .. c.reset .. "\n")
  end
  io.write("\n"); io.flush()
end

-- names: array de caminhos (strings) | oks: array paralelo de booleanos (ok/falha por item)
function M.tool_group_read_end(names, oks)
  local vis_len  = 9 + #tostring(#names) + 9  -- "⬤ Read ~ " + N + " Arquivos"
  local tw       = core.tw()
  local lines_up = math.max(1, math.ceil(vis_len / tw))
  io.write(string.format("\27[%dA\27[0J", lines_up))
  render_group_read_body(names, oks)
end

-- Replay: mesmo bloco final, sem fase amarela/cursor-up (já sabemos o resultado).
function M.tool_group_read_replay(names, oks)
  render_group_read_body(names, oks)
end

return M
