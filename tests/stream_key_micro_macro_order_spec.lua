-- Regressão Issue #368 / PR #369:
-- micro (chaves do mesmo provedor) esgota antes do macro (agents.defaults.model.fallbacks).
-- Valida o contrato estrutural do loop em parte_1.lua e a mensagem de falha final.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local pass, fail = 0, 0
local function T(name, ok)
  if ok then pass = pass + 1; print("  PASS " .. name)
  else fail = fail + 1; print("  FAIL " .. name) end
end

local src = assert(io.open("agent/api/request_stream/streamer/parte_1.lua", "r")):read("*a")

T("parte_1 requires key_rotation helper",
  src:find('require%("agent%.api%.request_stream%.streamer%.key_rotation"%)') ~= nil)

T("parte_1 derives key_rounds from api_key_count",
  src:find("api_key_count") ~= nil and src:find("key_rounds") ~= nil)

T("parte_1 nests attempts inside key rounds",
  src:find("for key_round") ~= nil and src:find("for attempt") ~= nil)

-- Macro fallback must appear AFTER the key-round loop closes.
local key_loop_pos = src:find("for key_round")
local record_pos = src:find("key_rotation%.record")
local rotate_pos = src:find("key_rotation%.rotate")
local macro_pos = src:find("fb%.tentar_fallbacks")
T("macro fallback is after key-round loop scaffolding",
  key_loop_pos and macro_pos and key_loop_pos < macro_pos)
T("failure is recorded before rotating to next key",
  record_pos and rotate_pos and record_pos < rotate_pos)
T("rotation of next key happens before macro fallback",
  rotate_pos and macro_pos and rotate_pos < macro_pos)

-- Only rotate while remaining key rounds exist.
T("rotation gated by key_round < key_rounds",
  src:find("key_round < key_rounds") ~= nil)

-- Fallback final message mentions multi-key attempts when applicable.
local fb_src = assert(io.open("agent/api/request_stream/streamer/fallback.lua", "r")):read("*a")
T("falha_final mentions tentativas por chave when keys_total > 1",
  fb_src:find("keys_total") ~= nil
  and fb_src:find("tentativas por chave") ~= nil)

-- Single-key path still has a sane max(1, ...) floor so zero-count never skips the loop entirely.
T("key_rounds floors at 1 via math.max",
  src:find("math%.max%(1,%s*tonumber%(ctx%.active%.api_key_count%)") ~= nil
  or src:find("math.max%(1, tonumber%(ctx.active.api_key_count%)") ~= nil)

print(string.format("\nSTREAM KEY MICRO→MACRO ORDER: %d passed, %d failed", pass, fail))
if fail > 0 then os.exit(1) end
