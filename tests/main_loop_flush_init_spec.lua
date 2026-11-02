-- tests/main_loop_flush_init_spec.lua — init de flush_msgs_start (Issue #363 / PR #364).
-- Origem: refactor/363-main-loop-srp — flush_init.compute.
-- Objetivo: trava de regressão para os três ramos de índice inicial de flush:
--   1) sessão com índice salvo → saved+1
--   2) legado com mensagens → max(1, #msgs-15)  (proteção Sandbox Blowout)
--   3) sessão vazia → #msgs+1
--
-- "E se isso mudar?": alteração na janela de 15, no off-by-one do índice
-- salvo ou no tratamento de sessão sem get_flush_index deve falhar aqui.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then
    print("OK:   " .. msg)
  else
    failures = failures + 1
    print("FAIL: " .. msg)
  end
end

local saved
package.loaded["session"] = {
  get_flush_index = function() return saved end,
}
package.loaded["agent.main_loop.flush_init"] = nil
local flush_init = require("agent.main_loop.flush_init")

-- --- Ramo 1: índice salvo ---
saved = 10
T(flush_init.compute({ msgs = {1,2,3,4,5,6,7,8,9,10,11,12} }) == 11,
  "sessão com índice salvo: saved+1")

saved = 0
T(flush_init.compute({ msgs = {1, 2} }) == 1,
  "índice salvo 0: 0+1 → 1")

saved = 42
T(flush_init.compute({ msgs = {} }) == 43,
  "índice salvo mesmo com msgs vazias: saved+1 (prioriza salvo)")

-- --- Ramo 2: legado (sem saved) ---
saved = nil
local legacy20 = {}
for i = 1, 20 do legacy20[i] = i end
T(flush_init.compute({ msgs = legacy20 }) == 5,
  "legado: max(1, #msgs-15) com 20 msgs → 5")

local legacy16 = {}
for i = 1, 16 do legacy16[i] = i end
T(flush_init.compute({ msgs = legacy16 }) == 1,
  "legado: #msgs=16 → max(1,1) → 1")

local legacy15 = {}
for i = 1, 15 do legacy15[i] = i end
T(flush_init.compute({ msgs = legacy15 }) == 1,
  "legado: #msgs=15 → max(1,0) → 1")

local short = {1, 2, 3}
T(flush_init.compute({ msgs = short }) == 1,
  "legado curto: max(1, 3-15) → 1")

-- --- Ramo 3: sessão vazia ---
T(flush_init.compute({ msgs = {} }) == 1,
  "sessão vazia: #msgs+1 → 1")

-- --- Ausência de get_flush_index (defesa defensiva do original) ---
package.loaded["session"] = {}  -- sem get_flush_index
package.loaded["agent.main_loop.flush_init"] = nil
flush_init = require("agent.main_loop.flush_init")
T(flush_init.compute({ msgs = legacy20 }) == 5,
  "session sem get_flush_index: cai no ramo legado")

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
