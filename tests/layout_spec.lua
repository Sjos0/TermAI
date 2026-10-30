package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local layout = require("ui.widgets.layout")
local largura = require("ui.largura")

local s = layout.split_equal(80, 3)
local sum = 0
for _, v in ipairs(s) do sum = sum + v end
T(sum == 80, "split_equal(80,3) soma 80")
local mx, mn = math.max(table.unpack(s)), math.min(table.unpack(s))
T(mx - mn <= 1, "diff max 1")

-- 2 segmentos redistribui
local s2 = layout.split_equal(80, 2)
sum = 0; for _, v in ipairs(s2) do sum = sum + v end
T(sum == 80 and #s2 == 2, "2 segmentos soma 80")

local line = layout.place({"✅ab", "日本語"}, layout.split_equal(20, 2), 20)
T(largura.colunas(line) == 20, "place nunca passa inner_w com emoji/CJK")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
