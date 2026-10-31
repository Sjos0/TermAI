-- tests/releitura_largura_335_spec.lua — #335: core.tw() relê após TTL sem tecla.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- Carrega core com terminal.lua real (não stub de tw).
local core = {}
require("ui.core.terminal")(core)

-- 1) invalidate zera cache
core.invalidate_size()
local a = core.tw()
T(type(a) == "number" and a > 0, "tw inicial numérico")

-- 2) cache estável dentro do TTL
local b = core.tw()
T(a == b, "cache estável dentro do TTL")

-- 3) após TTL, relê (mesmo valor se stty igual; o que importa é não ficar preso
--    a um W forçado). Força W falso e espera TTL.
core.invalidate_size()
-- força valor velho no cache interno via tw() depois de monkey-patch popen
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
-- ainda dentro do TTL: deve manter 40
T(core.tw() == 40, "dentro do TTL mantém 40")
-- espera TTL (1 s) + margem
local t0 = os.clock()
while os.clock() - t0 < 1.15 do end
T(core.tw() == 54, "após TTL relê stty → tw=54")
forced = 50
t0 = os.clock()
while os.clock() - t0 < 1.15 do end
T(core.tw() == 50, "após TTL relê stty → tw=50")
io.popen = old_popen
core.invalidate_size()

-- 4) medição de card nas três larguras (usa core.tw real com force)
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
  -- simula card usando a largura lida (como tool_replay faz com core.tw())
  local w = core.tw()
  T(w == tw, "core.tw()=" .. w .. " want " .. tw)
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
