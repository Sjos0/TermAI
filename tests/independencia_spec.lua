-- tests/independencia_spec.lua — card e bloco não se importam; fundo.lua puro.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end
local function read(p)
  local f = io.open(p, "r"); if not f then return "" end
  local t = f:read("*a"); f:close(); return t or ""
end
local card = read("ui/card.lua")
T(not card:find('require%("ui%.widgets'), "card nao importa ui.widgets")
T(not card:find('require%("ui/widgets'), "card nao importa ui/widgets path")
local function scan_dir(dir)
  local h = io.popen('find "' .. dir .. '" -name "*.lua" 2>/dev/null')
  if not h then return {} end
  local files = {}
  for line in h:lines() do files[#files+1] = line end
  h:close()
  return files
end
local bad = 0
for _, f in ipairs(scan_dir("ui/widgets")) do
  local t = read(f)
  if t:find('require%("ui%.card') or t:find('require%("ui/card') then
    bad = bad + 1
    print("FAIL dep: " .. f)
  end
end
T(bad == 0, "widgets nao importam ui.card")
-- fundo.lua se existir: sem require de tela
local fundo = read("ui/estilo/fundo.lua")
if fundo ~= "" then
  T(not fundo:find('require%("ui%.card') and not fundo:find('require%("ui%.widgets')
    and not fundo:find('require%("ui%.core') and not fundo:find('require%("ui%.misc'),
    "fundo.lua sem require de modulo de tela")
else
  T(true, "fundo.lua ainda nao existe (fase A ok)")
end
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
