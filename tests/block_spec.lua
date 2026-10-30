-- tests/block_spec.lua — #248 Block unitário
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path
local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local block = require("ui.widgets.block")
local largura = require("ui.largura")
local function vis(s) return largura.colunas((s or ""):gsub("\27%[[0-9;]*m", "")) end

-- TYPES
for _, t in ipairs({ "PLAIN", "ROUNDED", "DOUBLE", "THICK" }) do
  local b = block.new({ border_type = block.TYPE[t], borders = block.BORDERS.ALL })
  local lines = b:render({ w = 10, h = 3 })
  T(#lines == 3, t .. " h=3 -> 3 linhas")
  T(vis(lines[1]) == 10, t .. " largura visual 10")
end

-- BORDERS ALL
do
  local b = block.new({ borders = block.BORDERS.ALL, border_type = block.TYPE.PLAIN })
  local lines = b:render({ w = 80, h = 3 })
  T(#lines == 3, "render 80x3 = 3 linhas")
  T(vis(lines[1]) == 80 and vis(lines[2]) == 80 and vis(lines[3]) == 80, "cada linha largura 80")
  local plain = lines[1]:gsub("\27%[[0-9;]*m", "")
  T(plain:sub(1, 1) == "┌" and plain:find("┐", 1, true), "cantos PLAIN no topo")
end

-- inner + padding
do
  local b = block.new({
    borders = block.BORDERS.ALL,
    padding = { left = 1, right = 1, top = 0, bottom = 0 },
  })
  local inn = b:inner({ w = 10, h = 5, x = 1, y = 1 })
  T(inn.w == 6, "inner w=10 -2bordas -2pad =6 (got " .. inn.w .. ")")
  T(inn.h == 3, "inner h=5 -2bordas =3 (got " .. inn.h .. ")")
end

-- area menor que borda
do
  local b = block.new({ borders = block.BORDERS.ALL })
  local inn = b:inner({ w = 1, h = 1 })
  T(inn.w == 0 and inn.h == 0, "area pequena -> inner 0")
end

-- w impar
do
  local b = block.new({ borders = block.BORDERS.ALL })
  local lines = b:render({ w = 21, h = 3 })
  T(vis(lines[1]) == 21, "w impar 21")
end

-- responsivo: mesma instância, w muda
do
  local b = block.new({ borders = block.BORDERS.ALL })
  for _, w in ipairs({ 20, 40, 80, 120 }) do
    local lines = b:render({ w = w, h = 3 })
    T(#lines == 3 and vis(lines[1]) == w, "responsivo w=" .. w)
  end
end

-- sem utf8.len no block
do
  local src = assert(io.open("ui/widgets/block/render.lua"):read("*a"))
  T(not src:find("utf8%.len"), "render nao usa utf8.len")
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
