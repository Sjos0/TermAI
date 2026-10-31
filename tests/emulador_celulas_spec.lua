-- tests/emulador_celulas_spec.lua — #282 T1: emulador por célula (CSI/SGR).
-- Não importa ui/largura, ui/card, ui/widgets/*; não remove SGR antes de medir.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- ── Emulador por célula (movido para tests/helpers/emulador_celulas.lua, #331) ──
local novo_emulador = require("tests.helpers.emulador_celulas").novo

-- Reexport para specs que carregarem este arquivo via package.loaded.
package.loaded["tests.emulador_celulas"] = {
  novo = novo_emulador,
}

-- ── Verificação mínima obrigatória (#282 T1) ────────────────────────────────
do
  local em = novo_emulador(10, 5)
  em.feed("\27[48;5;52mABC\27[0m")
  local c1 = em.celula(1, 1)
  local c2 = em.celula(1, 2)
  local c3 = em.celula(1, 3)
  local c4 = em.celula(1, 4)
  T(c1.fundo == 52 and c1.glifo == "A", "col1 fundo 52 glifo A (got fundo=" .. tostring(c1.fundo) .. " g=" .. c1.glifo .. ")")
  T(c2.fundo == 52 and c2.glifo == "B", "col2 fundo 52 glifo B")
  T(c3.fundo == 52 and c3.glifo == "C", "col3 fundo 52 glifo C")
  T(c4.fundo == nil, "col4 sem fundo apos reset (got " .. tostring(c4.fundo) .. ")")
end

-- SGR texto 38;5;n
do
  local em = novo_emulador(8, 3)
  em.feed("\27[38;5;231mX\27[0m")
  local c = em.celula(1, 1)
  T(c.texto == 231 and c.glifo == "X", "fg 231 no glifo X")
  T(em.celula(1, 2).texto == nil, "fg limpo apos reset")
end

-- ESC[nA + reescrita
do
  local em = novo_emulador(10, 5)
  em.feed("AAAA\nBBBB")
  em.feed("\27[1A\27[2KCCCC")
  T(em.celula(1, 1).glifo == "C", "ESC[1A+2K reescreve linha 1")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
