package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local l = require("ui.largura")
local cases = {
  {"✓", 1}, {"✗", 1}, {"★", 1}, {"➡", 1}, {"⚠", 1},
  {"⚠️", 2}, {"✅", 2}, {"❌", 2}, {"⚡", 2},
}
for _, c in ipairs(cases) do
  T(l.colunas(c[1]) == c[2], string.format("%s = %d (got %d)", c[1], c[2], l.colunas(c[1])))
end
local card = require("ui.card")
local BG, FG = "\27[48;5;234m", "\27[38;5;255m"
for _, tw in ipairs({40, 50, 80}) do
  for _, text in ipairs({"teste ✓ ok", "saida ➡ fim"}) do
    local rows = card.body_rows({text}, tw)
    local line = card.bg_row(BG, FG, rows[1].prefix, FG, rows[1].text, tw)
    T(l.colunas(line) == tw, string.format("body '%s' tw=%d vis=%d", text, tw, l.colunas(line)))
  end
  local h = card.bg_row(BG, FG, "⬤ ", FG, "Exec (x)", tw)
  T(l.colunas(h) == tw, "header tw=" .. tw .. " vis=" .. l.colunas(h))
end
local core = require("ui.core")
core.tw = function() return 50 end
local writes = {}
local rw = io.write
io.write = function(...) writes[#writes + 1] = table.concat({...}) end
require("ui.tools_init.executor").tool_replay("Exec (echo)", "teste ✓ ok\nsaida ➡ fim", true)
io.write = rw
for ln in (table.concat(writes) .. "\n"):gmatch("([^\n]*)\n") do
  if ln ~= "" then T(l.colunas(ln) == 50, "replay vis=" .. l.colunas(ln)) end
end
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
