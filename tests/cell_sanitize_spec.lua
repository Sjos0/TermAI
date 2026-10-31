package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local san = require("ui.cell.sanitize")
local t, d
t, d = san.sanitize_line("a\tb")
T(not t:find("\t"), "TAB expandido")
T(t:find("a") and t:find("b"), "conteúdo preservado")
t, d = san.sanitize_line("x\27[48;5;196my\27[0mz")
T(not t:find("48;5;196"), "SGR fundo descartado")
t, d = san.sanitize_line("a\27[31mb")
T(t:find("31"), "SGR texto mantido")
t, d = san.sanitize_line("a\r\27[Kb")
T(d >= 1, "CR/CSI contados como descarte")
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
