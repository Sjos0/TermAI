package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local fundo = require("ui.estilo.fundo")
local bg = "\27[48;5;236m"
T(fundo.fundo_seguro(bg, "abc") == "abc", "sem reset: inalterado")
local t = fundo.fundo_seguro(bg, "x\27[0my")
T(t:find("\27[0m" .. bg, 1, true) ~= nil, "com reset: reaplica bg")
T(fundo.fundo_seguro("", "a\27[0mb") == "a\27[0mb", "bg vazio: inalterado")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
