-- tests/card_tab_expand_spec.lua — #307 TAB expandido antes do card
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local largura = require("ui.largura")
local card = require("ui.card")
local core = require("ui.core")

T(not largura.expand_tabs("a\tb"):find("\t", 1, true), "expand_tabs remove TAB")
T(largura.expand_tabs("a\tb"):find(" ", 1, true), "expand_tabs gera espaços")
-- tab at col 0 → 8 spaces
T(#largura.expand_tabs("\t") == 8, "TAB no início = 8 espaços")

core.tw = function() return 50 end
local c = core.c
local writes = {}
local rw = io.write
io.write = function(...) writes[#writes+1]=table.concat({...}) end
local executor = require("ui.tools_init.executor")
executor.tool_replay("Exec (tab)", "linhas:\t38\n1\t13", true)
io.write = rw
local out = table.concat(writes)
T(not out:find("\t", 1, true), "replay não emite TAB cru")
-- células com fundo
T(out:find("38", 1, true) ~= nil, "conteúdo 38 presente")

-- body_rows
local rows = card.body_rows({"x\ty"}, 40)
T(not rows[1].text:find("\t", 1, true), "body_rows sem TAB")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
