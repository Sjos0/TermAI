package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local l = require("ui.largura")
T(l.colunas("⬤") == 1, "⬤ = 1 coluna (got " .. l.colunas("⬤") .. ")")
T(l.colunas("⬤ ") == 2, "⬤+espaço = 2")
T(l.colunas("⬛") == 2, "U+2B1B ainda wide")
T(l.colunas("⭐") == 2, "U+2B50 ainda wide")
local card = require("ui.card")
local BG, FG = "\27[48;5;234m", "\27[38;5;255m"
for _, tw in ipairs({40, 50, 80}) do
  local h = card.bg_row(BG, FG, "⬤ ", FG, "Exec (x)", tw)
  T(l.colunas(h) == tw, "header tw=" .. tw .. " vis=" .. l.colunas(h))
  local rows = card.body_rows({"linha"}, tw)
  local body = card.bg_row(BG, FG, rows[1].prefix, FG, rows[1].text, tw)
  T(l.colunas(body) == tw, "corpo tw=" .. tw .. " vis=" .. l.colunas(body))
end
-- caminho real
local core = require("ui.core")
core.tw = function() return 50 end
local writes = {}
local rw = io.write
io.write = function(...) writes[#writes + 1] = table.concat({...}) end
require("ui.tools_init.executor").tool_replay("Exec (echo)", "ok", true)
io.write = rw
for ln in (table.concat(writes) .. "\n"):gmatch("([^\n]*)\n") do
  if ln ~= "" then
    T(l.colunas(ln) == 50, "replay vis=" .. l.colunas(ln))
  end
end
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
