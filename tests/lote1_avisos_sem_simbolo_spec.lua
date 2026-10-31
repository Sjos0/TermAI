-- tests/lote1_avisos_sem_simbolo_spec.lua
-- Issue #325 — lote 1 (ui/, channels/, providers/): símbolos de status viram
-- palavras em inglês. Trava o ponto que o gerente anexou ao lote:
--   1) o aviso que antes trazia ⚠️ (U+26A0 + seletor de variação U+FE0F) agora é
--      texto puro, sem o símbolo e sem o VS16 que deixava o card "1 coluna curto";
--   2) a mensagem de aviso cabe em tw 40, 50 e 54, sem linha passar de tw.
-- Roda o código REAL (ui/misc.lua), apenas capturando io.write.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function check(cond, msg)
  if cond then
    print("ok   - " .. msg)
  else
    failures = failures + 1
    print("FAIL - " .. msg)
  end
end

local largura = require("ui.largura")
local misc    = require("ui.misc")

local _write = io.write
local function capturar(fn)
  local buf = {}
  io.write = function(...)
    local t = table.pack(...)
    for i = 1, t.n do buf[#buf + 1] = tostring(t[i]) end
  end
  local ok, err = pcall(fn)
  io.write = _write
  assert(ok, err)
  return table.concat(buf)
end

local saida = capturar(function() misc.agent_limit(10) end)

-- U+26A0 em UTF-8 = \226\154\160 ; U+FE0F (VS16) = \239\184\143
check(saida:find("\226\154\160", 1, true) == nil, "aviso sem o símbolo ⚠ (U+26A0)")
check(saida:find("\239\184\143", 1, true) == nil, "aviso sem o seletor U+FE0F (VS16)")
check(saida:find("[WARN]", 1, true) ~= nil, "aviso em palavras: [WARN]")

for _, tw in ipairs({ 40, 50, 54 }) do
  local pior = 0
  for ln in (saida .. "\n"):gmatch("([^\n]*)\n") do
    if ln ~= "" then
      local w = largura.colunas(ln)
      if w > pior then pior = w end
    end
  end
  check(pior <= tw, ("aviso cabe em tw=%d (pior=%d)"):format(tw, pior))
end

if failures > 0 then
  print(("\nFAIL  lote1_avisos_sem_simbolo_spec: %d falha(s)"):format(failures))
  os.exit(1)
end
print("\nPASS  lote1_avisos_sem_simbolo_spec")
