-- tests/markdown_hr_tw_spec.lua — linha horizontal (--- / ***) ocupa exatamente core.tw() colunas.
-- Passa pelo caminho REAL: renderer.render → lib/renderer → renderer.markdown.render_line.
-- Sem copiar lógica de produção: só mede a saída do renderer.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

-- tw controlável: o stub devolve TW a cada chamada (sem cache), imitando core.tw() real.
local TW = 80
package.loaded["ui.core.terminal"] = function(core)
  function core.tw() return TW end
  function core.th() return 24 end
  function core.invalidate_size() end
end

local renderer = require("renderer")

local function strip_ansi(s) return (s:gsub("\27%[[0-9;]*m", "")) end
local function count_glyph(s, g) return select(2, strip_ansi(s):gsub(g, "")) end
local function line_count(s) return select(2, (s .. "\n"):gsub("[^\n]*\n", "")) end

local function hr_lines(raw)
  local out = {}
  for ln in (raw .. "\n"):gmatch("([^\n]*)\n") do
    if count_glyph(ln, "─") > 0 then out[#out + 1] = ln end
  end
  return out
end

for _, tw in ipairs({ 40, 50, 54, 80 }) do
  for _, md_hr in ipairs({ "---", "***" }) do
    TW = tw
    local raw = renderer.render("linha antes\n" .. md_hr .. "\nlinha depois")
    local hrs = hr_lines(raw)
    T(#hrs == 1, string.format("[tw=%d %s] exatamente 1 linha horizontal", tw, md_hr))
    if #hrs == 1 then
      local w = count_glyph(hrs[1], "─")
      T(w == tw, string.format("[tw=%d %s] largura=%d esperado=%d", tw, md_hr, w, tw))
    end
    T(line_count(raw) == 3, string.format("[tw=%d %s] saida=3 linhas (sem wrap)", tw, md_hr))
  end
end

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
