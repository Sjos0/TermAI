-- tests/releitura_largura_335_spec.lua — #335/#341: core.tw() relê após TTL com tempo de parede.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local core = {}
require("ui.core.terminal")(core)

core.invalidate_size()
local a = core.tw()
T(type(a) == "number" and a > 0, "tw inicial numérico")
T(core.tw() == a, "cache estável dentro do TTL")

local old_popen = io.popen
local forced = 40
io.popen = function(cmd)
  if type(cmd) == "string" and cmd:find("stty size", 1, true) then
    return {
      read = function() return "24 " .. tostring(forced) end,
      close = function() end,
    }
  end
  return old_popen(cmd)
end
core.invalidate_size()
T(core.tw() == 40, "stty forçado → tw=40")
forced = 54
T(core.tw() == 40, "dentro do TTL mantém 40")
-- espera de parede (não laço de CPU): #341
os.execute("sleep 2")
T(core.tw() == 54, "após sleep 2s relê stty → tw=54")
forced = 50
os.execute("sleep 2")
T(core.tw() == 50, "após sleep 2s relê stty → tw=50")
io.popen = old_popen
core.invalidate_size()

local card = require("ui.card")
local largura = require("ui.largura")
local BG, FG = "\27[48;5;234m", "\27[38;5;255m"
for _, tw in ipairs({40, 50, 54}) do
  forced = tw
  io.popen = function(cmd)
    if type(cmd) == "string" and cmd:find("stty size", 1, true) then
      return { read = function() return "24 " .. tostring(forced) end, close = function() end }
    end
    return old_popen(cmd)
  end
  core.invalidate_size()
  local w = core.tw()
  T(w == tw, "core.tw()=" .. tostring(w) .. " want " .. tw)
  local rows = card.body_rows({"teste ✓ ok"}, w)
  local line = card.bg_row(BG, FG, rows[1].prefix, FG, rows[1].text, w)
  T(largura.colunas(line) == w, "body vis=" .. largura.colunas(line) .. " tw=" .. w)
  local h = card.bg_row(BG, FG, "⬤ ", FG, "Exec (x)", w)
  T(largura.colunas(h) == w, "header vis=" .. largura.colunas(h) .. " tw=" .. w)
end
io.popen = old_popen
core.invalidate_size()

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
