-- tests/rodape_tokens_spec.lua — #277 rodapé Tokens / place_natural / tw.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local core = require("ui.core")
local largura = require("ui.largura")
local writes = {}
local real_write = io.write
io.write = function(...)
  local s = table.concat({...})
  writes[#writes + 1] = s
  return real_write(...)
end

local function plain_join()
  return table.concat(writes):gsub("\27%[[0-9;:?]*[A-Za-z]", "")
end

local misc = require("ui.misc")

for _, tw in ipairs({ 30, 40, 50, 80 }) do
  package.loaded["ui.core"].tw = function() return tw end
  -- ao vivo
  writes = {}
  misc.footer(44124, 1000000, 1300, "17:55")
  local live = plain_join()
  T(live:find("Tokens:", 1, true) ~= nil, "tw=" .. tw .. " vivo tem Tokens:")
  T(not live:find("tokens:", 1, true), "tw=" .. tw .. " vivo sem tokens: minúsculo")
  -- cada linha de conteúdo do block deve ter largura visual tw (bordas inclusas nas lines do block)
  local lines = {}
  for ln in (live .. "\n"):gmatch("([^\n]*)\n") do
    if ln:find("┌", 1, true) or ln:find("│", 1, true) or ln:find("└", 1, true) then
      lines[#lines + 1] = ln
    end
  end
  if tw >= 20 then
    for i, ln in ipairs(lines) do
      local v = largura.colunas(ln)
      T(v == tw, "tw=" .. tw .. " vivo linha " .. i .. " largura " .. v)
    end
    if tw >= 50 then
      T(live:find("17:55", 1, true) ~= nil, "tw=" .. tw .. " vivo tem relógio")
      T(live:find("seg", 1, true) ~= nil or live:find("1.3", 1, true) ~= nil, "tw=" .. tw .. " vivo tem tempo")
    end
  end
  -- replay (só hora)
  writes = {}
  misc.footer(44124, 1000000, nil, "17:55")
  local rep = plain_join()
  T(rep:find("Tokens:", 1, true) ~= nil, "tw=" .. tw .. " replay Tokens:")
  if tw >= 40 then
    T(rep:find("17:55", 1, true) ~= nil, "tw=" .. tw .. " replay tem hora")
  end
end

io.write = real_write
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
