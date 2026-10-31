package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local wrap = require("ui.widgets.block.wrap")
local function check(word, max_w, label)
  local parts = wrap.wrap_text(word, max_w)
  local joined = table.concat(parts)
  T(joined == word, label .. " (got " .. #joined .. " want " .. #word .. ")")
end
check(string.rep("A", 80), 18, "ASCII longo")
check(string.rep("字", 40), 18, "CJK")
check(string.rep("🎉", 20), 10, "emoji")
check("curta", 40, "menor que largura")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
