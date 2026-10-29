-- tests/retry_card_inplace_spec.lua — show_retry atualiza no lugar (não empilha)
-- e clear_retry_lines zera o contador (não come a mensagem do usuário depois).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- stub tw
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

-- 1) três tentativas → não deve haver 6 linhas de conteúdo empilhadas sem cursor-up
writes = {}
retry.show_retry(1, 5, "Sem resposta do servidor", 1)
retry.show_retry(2, 5, "Sem resposta do servidor", 2)
retry.show_retry(3, 5, "Sem resposta do servidor", 4)
local joined = table.concat(writes)
local ups = 0
for _ in joined:gmatch("\27%[%d+A") do ups = ups + 1 end
T(ups >= 2, "show_retry reutiliza ESC[nA para redesenhar (ups=" .. ups .. ")")
T(joined:find("Tentativa 3/5", 1, true) ~= nil, "última tentativa visível é 3/5")
T(joined:find("⚠", 1, true) == nil and joined:find("⏳", 1, true) == nil, "sem emojis no card")

-- 2) clear zera e não deixa contador residual alto
retry.clear_retry_lines()
writes = {}
retry.show_retry(1, 5, "x", 0)
retry.clear_retry_lines()
-- após clear, novo show começa do zero (sem A grande)
local nA = 0
for n in table.concat(writes):gmatch("\27%[(%d+)A") do nA = nA + tonumber(n) end
T(nA <= 3, "após clear, cursor-up residual baixo (nA=" .. nA .. ")")

-- 3) show_api_error desenha [ERRO]
writes = {}
retry.show_api_error("Falha após 5 tentativas — Sem resposta do servidor")
T(table.concat(writes):find("%[ERRO%]", 1) ~= nil, "show_api_error emite [ERRO]")

io.write = real_write
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
