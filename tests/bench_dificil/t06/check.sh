#!/bin/sh
d="$1"
cd "$d" || exit 1
lua5.4 -e '
local t = dofile("lib/texto.lua")
local function junta(x) return table.concat(x, "|") end
local function eq(a, b) if a ~= b then error("esperado " .. b .. " obtido " .. a) end end
eq(junta(t.dividir("a,b,,c", ",")), "a|b||c")
eq(junta(t.dividir("a,", ",")), "a|")
eq(junta(t.dividir("abc", ",")), "abc")
eq(junta(t.pagina({1,2,3,4,5}, 1, 2)), "1|2")
eq(junta(t.pagina({1,2,3,4,5}, 2, 2)), "3|4")
eq(junta(t.pagina({1,2,3,4,5}, 3, 2)), "5")
' || exit 1
[ -f ok.txt ] && grep -q "OK" ok.txt
