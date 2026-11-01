-- tests/messages_hr_display_spec.lua — HR (--- / ***) em ai_msg / ai_msg_stream
-- não produz remanescente de ─ na linha seguinte (Issue #356).
-- Cobre o caminho de display (ui.messages), não só o renderer isolado.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local TW = 80
package.loaded["ui.core.terminal"] = function(core)
  function core.tw() return TW end
  function core.th() return 24 end
  function core.invalidate_size() end
end

-- Captura de io.write
local captured = {}
local real_write = io.write
io.write = function(...)
  local parts = {...}
  for i = 1, #parts do captured[#captured + 1] = tostring(parts[i]) end
end

local messages = require("ui.messages")
local core = require("ui.core")
local largura = require("ui.largura")

local function strip_ansi(s) return (s:gsub("\27%[[0-9;]*m", "")) end
local function count_glyph(s, g) return select(2, strip_ansi(s):gsub(g, "")) end

local function reset_capture()
  captured = {}
end

local function join_capture()
  return table.concat(captured)
end

local function lines_of(s)
  local out = {}
  for ln in (s .. "\n"):gmatch("([^\n]*)\n") do
    out[#out + 1] = ln
  end
  return out
end

local function hr_line_indices(lines)
  local idx = {}
  for i, ln in ipairs(lines) do
    if count_glyph(ln, "─") > 0 then idx[#idx + 1] = i end
  end
  return idx
end

for _, tw in ipairs({ 40, 50, 54, 80 }) do
  for _, md_hr in ipairs({ "---", "***" }) do
    for _, fn_name in ipairs({ "ai_msg", "ai_msg_stream" }) do
      TW = tw
      reset_capture()
      local input = "antes\n" .. md_hr .. "\ndepois"
      messages[fn_name](input)
      local out = join_capture()
      local lines = lines_of(out)
      local hrs = hr_line_indices(lines)

      -- Trava #356: nenhuma linha do output pode exceder tw colunas visuais.
      -- Sem isto o spec e cego: o HR sai inteiro com tw glifos mesmo com o
      -- defeito reintroduzido, e o remanescente e artefato do terminal
      -- pelo overflow, nao ha "─" literal a mais na string.
      local worst_w, worst_i = 0, 0
      for i, ln in ipairs(lines) do
        local wdt = largura.colunas(strip_ansi(ln))
        if wdt > worst_w then worst_w, worst_i = wdt, i end
      end
      T(worst_w <= tw, string.format("[tw=%d %s %s] largura maxima=%d <= tw=%d (pior linha=%d)",
        tw, md_hr, fn_name, worst_w, tw, worst_i))

      T(#hrs == 1, string.format("[tw=%d %s %s] exatamente 1 linha com ─", tw, md_hr, fn_name))
      if #hrs == 1 then
        local hi = hrs[1]
        local w = count_glyph(lines[hi], "─")
        T(w == tw, string.format("[tw=%d %s %s] glifos ─ =%d esperado=%d", tw, md_hr, fn_name, w, tw))
        -- Linha seguinte não deve conter ─ residual
        if hi < #lines then
          local next_has = count_glyph(lines[hi + 1], "─") > 0
          T(not next_has, string.format("[tw=%d %s %s] linha seguinte sem ─ residual", tw, md_hr, fn_name))
        else
          T(true, string.format("[tw=%d %s %s] sem linha seguinte (ok)", tw, md_hr, fn_name))
        end
      end
    end
  end
end

-- Texto normal continua com prefixo de continuação (espaço)
do
  TW = 54
  reset_capture()
  messages.ai_msg("uma linha de texto normal suficientemente longa para wrap")
  local out = join_capture()
  -- Deve haver ao menos uma linha que começa com espaço (continuação) ou a primeira com ⬤
  local has_bullet = out:find("⬤", 1, true) ~= nil
  T(has_bullet, "texto normal: ainda emite ⬤ na primeira linha")
end

io.write = real_write
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
