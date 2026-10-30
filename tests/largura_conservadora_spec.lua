-- tests/largura_conservadora_spec.lua — #202: colunas/cortar conservadores; bg_row não estoura tw.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local largura = require("ui.largura")
local card = require("ui.card")

local two_check = "✅✅"
local three_check = "✅✅✅"

T(largura.colunas("ab") == 2, 'colunas(ab) == 2')
T(largura.colunas(two_check) == 4, 'colunas(two emoji) == 4')
T(largura.colunas("\t") == 8, 'colunas(tab) == 8')

local cut = largura.cortar(three_check, 5)
T(type(cut) == "string" and #cut > 0, "cortar retorna string")
T(largura.colunas(cut) <= 5, "cortar colunas <= 5 got " .. tostring(largura.colunas(cut)))
T(utf8.len(cut) ~= nil, "cortar UTF-8 valido")

local tw = 20
local row = card.bg_row("\27[48;5;234m", "", "X ", "", "Exec " .. two_check, tw)
local plain = row:gsub("\27%[[0-9;]*m", "")
T(card.width(plain) <= tw, "bg_row cabe em tw w=" .. card.width(plain))

T(card.width(two_check) == largura.colunas(two_check), "card.width delega")
T(card.cut("abcdefghij", 5) == largura.cortar("abcdefghij", 5), "card.cut delega")

package.loaded["ui.core"] = {
  c = { bg = "\27[48;5;234m", bold = "", white = "" },
  tw = function() return 40 end,
}
package.loaded["ui.tools_init.header"] = nil
local header = require("ui.tools_init.header")
local hv = header.header_vis_len("Exec", two_check, 40)
T(type(hv) == "number" and hv >= 8, "header_vis_len emoji hv=" .. tostring(hv))

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
