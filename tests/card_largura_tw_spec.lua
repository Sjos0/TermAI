-- tests/card_largura_tw_spec.lua — card pinta exatamente tw colunas (header/corpo/replay).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local card = require("ui.card")
local largura = require("ui.largura")
local core = require("ui.core")
local BG, FG, DIM = "\27[48;5;234m", "\27[38;5;255m", "\27[38;5;245m"

local function vis(s) return largura.colunas(s) end

for _, tw in ipairs({40, 50, 80}) do
  local h = card.bg_row(BG, FG, "▶ ", FG, "Exec (x)", tw)
  T(vis(h) == tw, "header tw=" .. tw .. " vis=" .. vis(h))
  local rows = card.body_rows({"linha"}, tw)
  local body = card.bg_row(BG, FG, rows[1].prefix, FG, rows[1].text, tw)
  T(vis(body) == tw, "corpo tw=" .. tw .. " vis=" .. vis(body))
  rows = card.body_rows({"a","b","c","d","e","f"}, tw) -- max+overflow
  for i, r in ipairs(rows) do
    local line = card.bg_row(BG, FG, r.prefix, r.dim and DIM or FG, r.text, tw)
    T(vis(line) == tw, "row" .. i .. " tw=" .. tw .. " vis=" .. vis(line))
  end
end

-- caminho real tool_replay
core.tw = function() return 50 end
local writes = {}
local rw = io.write
io.write = function(...) writes[#writes+1]=table.concat({...}) end
local executor = require("ui.tools_init.executor")
executor.tool_replay("Exec (echo)", "col1\ncol2", true)
io.write = rw
local out = table.concat(writes)
local nlines = 0
for ln in (out.."\n"):gmatch("([^\n]*)\n") do
  if ln ~= "" then
    nlines = nlines + 1
    local v = vis(ln)
    T(v == 50, "replay linha vis=" .. v .. " want 50")
  end
end
T(nlines >= 2, "replay emitiu linhas")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
