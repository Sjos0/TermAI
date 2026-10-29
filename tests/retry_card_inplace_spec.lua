-- tests/retry_card_inplace_spec.lua — card de retry in-place, sem emoji, transição 2→1 linha.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

package.loaded["ui.core"] = {
  c = {
    reset="\27[0m", gray="\27[38;5;245m", orange="\27[38;5;208m",
    bg_error="\27[48;5;52m", bg="\27[48;5;234m",
  },
  tw = function() return 40 end,
}
package.loaded["ui.card"] = {
  cut = function(s, max)
    s = tostring(s or "")
    if #s <= max then return s end
    return s:sub(1, max)
  end,
  bg_row = function(bg, pc, prefix, tc, text, tw)
    return bg .. pc .. prefix .. tc .. text .. "\27[0m"
  end,
}

local writes = {}
local real_write = io.write
io.write = function(...)
  local s = table.concat({...})
  writes[#writes + 1] = s
  return real_write(...)
end

local retry = require("ui.spinner.retry")

writes = {}
retry.show_retry(1, 5, "Sem resposta do servidor", 1)
retry.show_retry(2, 5, "Sem resposta do servidor", 2)
retry.show_retry(3, 5, "Sem resposta do servidor", 4)
local joined = table.concat(writes)
local ups = 0
for _ in joined:gmatch("\27%[%d+A") do ups = ups + 1 end
T(ups >= 2, "show_retry reutiliza ESC[nA (ups=" .. ups .. ")")
T(joined:find("Tentativa 3/5", 1, true) ~= nil, "última tentativa visível é 3/5")
T(joined:find("⚠", 1, true) == nil and joined:find("⏳", 1, true) == nil, "sem emojis")

-- Transição 2 linhas (com wait) → 1 linha (wait=0): deve ESC[2A
writes = {}
retry.clear_retry_lines()
retry.show_retry(4, 5, "timeout", 2)
local after4 = table.concat(writes)
writes = {}
retry.show_retry(5, 5, "timeout", 0)
local after5 = table.concat(writes)
T(after5:find("\27%[2A", 1, true) ~= nil or after5:find("\27%[1A", 1, true) ~= nil,
  "5/5 apaga card anterior antes de redesenhar")
T(after5:find("Tentativa 5/5", 1, true) ~= nil, "mostra 5/5")
T(after5:find("Aguardando", 1, true) == nil, "5/5 sem linha de espera")

-- clear + residual baixo
retry.clear_retry_lines()
writes = {}
retry.show_retry(1, 5, "x", 0)
retry.clear_retry_lines()
local nA = 0
for n in table.concat(writes):gmatch("\27%[(%d+)A") do nA = nA + tonumber(n) end
T(nA <= 3, "após clear, cursor-up residual baixo (nA=" .. nA .. ")")

-- show_api_error substitui e não deixa contador alto
writes = {}
retry.show_retry(5, 5, "fim", 0)
retry.show_api_error("Falha após 5 tentativas — Sem resposta do servidor")
local err = table.concat(writes)
T(err:find("%[ERRO%]", 1) ~= nil, "show_api_error emite [ERRO]")
T(err:find("48;5;52", 1, true) ~= nil, "erro usa fundo bg_error")

-- responsivo: tw estreito não quebra (cut)
package.loaded["ui.core"].tw = function() return 20 end
package.loaded["ui.spinner.retry"] = nil
-- re-require won't reload module state easily; call with short tw via existing module
-- (module already loaded; tw() is looked up each paint — OK)
writes = {}
retry.show_retry(1, 3, "erro bem longo que deveria ser cortado na largura", 0)
T(#table.concat(writes) > 0, "tw=20 ainda desenha card")

io.write = real_write
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
