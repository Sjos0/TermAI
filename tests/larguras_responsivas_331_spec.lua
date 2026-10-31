-- tests/larguras_responsivas_331_spec.lua — #331: nada com largura fixa na TUI.
-- Prova, no caminho REAL de produção, três propriedades para larguras de
-- celular 40 / 50 / 54 / 80:
--   (a) nenhuma linha renderizada excede tw (nem uma célula a mais);
--   (b) resize no meio do uso (54 → 40 → 54) não deixa linha residual;
--   (c) card com mais linhas que a altura da tela (th = 27) não quebra o cursor.
-- tw/th são injetados via stub de core.tw/core.th (mesmo padrão de
-- card_largura_tw_spec.lua); a grade é lida pelo emulador por célula.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local core     = require("ui.core")
local largura  = require("ui.largura")
local emulador = require("tests.helpers.emulador_celulas")
local executor = require("ui.tools_init.executor")

local WIDTHS = { 40, 50, 54, 80 }
local orig_tw, orig_th = core.tw, core.th
local function set_tw(w) core.tw = function() return w end end
local function set_th(h) core.th = function() return h end end

local function capture(fn)
  local buf, orig = {}, io.write
  io.write = function(...) for _, v in ipairs({ ... }) do buf[#buf + 1] = tostring(v) end end
  local ok, err = pcall(fn)
  io.write = orig
  assert(ok, err)
  return table.concat(buf)
end

local function linhas(raw)
  local t = {}
  for ln in (raw .. "\n"):gmatch("([^\n]*)\n") do t[#t + 1] = ln end
  return t
end

-- Coluna mais à direita (1-based) onde aparece o glifo, em qualquer linha.
local function max_coluna(em, glifo)
  local maxc = 0
  for _, row in ipairs(em.grid) do
    for c = 1, #row do
      if row[c] and row[c].glifo == glifo and c > maxc then maxc = c end
    end
  end
  return maxc
end

-- ══════════════════════════════════════════════════════════════════════════
print("\n── (a) nenhuma linha excede tw (40 / 50 / 54 / 80) ──")
-- ══════════════════════════════════════════════════════════════════════════

local CORPO = {}
for i = 1, 30 do CORPO[i] = "resultado " .. i .. " com acentuação ção " .. string.rep("x", 40) end
CORPO = table.concat(CORPO, "\n")

for _, tw in ipairs(WIDTHS) do
  set_tw(tw)
  set_th(27)

  -- régua responsiva (core.regua) com prefixo de 2 colunas
  local sep = "  " .. core.regua(45, 2)
  T(largura.colunas(sep) <= tw,
    string.format("[a tw=%d] régua + prefixo <= tw (w=%d)", tw, largura.colunas(sep)))

  -- divisória de tw cheio (ui.misc.divider)
  local dline = linhas(capture(function() require("ui.misc").divider() end))[1] or ""
  T(largura.colunas(dline) == tw,
    string.format("[a tw=%d] divider == tw (w=%d)", tw, largura.colunas(dline)))

  -- card de tool com corpo longo: nenhuma linha passa de tw
  local out = capture(function()
    executor.tool_start("Exec | comando com saída longa e acentuação ção")
    executor.tool_end("Exec | comando com saída longa e acentuação ção", CORPO, true)
  end)
  local pior = 0
  for _, ln in ipairs(linhas(out)) do
    if ln ~= "" then
      local w = largura.colunas(ln)
      if w > pior then pior = w end
    end
  end
  T(pior <= tw, string.format("[a tw=%d] card <= tw (pior=%d)", tw, pior))
end

-- ══════════════════════════════════════════════════════════════════════════
print("\n── (b) resize 54 → 40 → 54 sem linha residual ──")
-- ══════════════════════════════════════════════════════════════════════════

-- (b1) tela real de menu (cabeçalho começa com cls) redesenhada após encolher.
do
  local view = require("commands.config.menus.request.view")
  local em = emulador.novo(60, 40)

  set_th(27)
  set_tw(54)
  em.feed(capture(function() view.print_header() end))
  local w1 = max_coluna(em, "─")
  T(w1 > 40, "b1: com tw=54 o separador passa de 40 colunas (col=" .. w1 .. ")")

  set_tw(40)
  em.feed(capture(function() view.print_header() end))
  local w2 = max_coluna(em, "─")
  T(w2 > 0, "b1: com tw=40 o separador continua visível (col=" .. w2 .. ")")
  T(w2 <= 40, "b1: após encolher p/ 40, nada além de 40 (col=" .. w2 .. ")")

  set_tw(54)
  em.feed(capture(function() view.print_header() end))
  local w3 = max_coluna(em, "─")
  T(w3 > 40, "b1: ao voltar p/ 54 o separador volta a passar de 40 (col=" .. w3 .. ")")
end

-- (b2) mesma linha, sem cls: a régua encolhe e o \27[K apaga a sobra.
do
  local em = emulador.novo(60, 10)

  set_tw(54)
  em.feed("\r" .. core.regua(45, 2) .. "\27[K")
  local antes = max_coluna(em, "─")
  T(antes == 45, "b2: com tw=54 a régua tem 45 traços (col=" .. antes .. ")")

  set_tw(40)
  em.feed("\r" .. core.regua(45, 2) .. "\27[K")
  local depois = max_coluna(em, "─")
  T(depois == 36, "b2: com tw=40 a régua encolhe p/ 36 (col=" .. depois .. ")")

  local sobra = 0
  for c = depois + 1, 60 do
    if em.celula(1, c).glifo == "─" then sobra = sobra + 1 end
  end
  T(sobra == 0, "b2: \\27[K apagou a sobra (traços residuais=" .. sobra .. ")")
end

-- ══════════════════════════════════════════════════════════════════════════
print("\n── (c) card mais alto que a tela (th=27) não quebra o cursor ──")
-- ══════════════════════════════════════════════════════════════════════════

for _, tw in ipairs(WIDTHS) do
  set_tw(tw)
  set_th(27)

  local corpo = {}
  for i = 1, 200 do corpo[i] = "linha " .. i .. " de um corpo bem maior que a tela" end
  corpo = table.concat(corpo, "\n")

  local ok, out = pcall(function()
    return capture(function()
      executor.tool_start("Exec | sleep 1")
      executor.tool_end("Exec | sleep 1", corpo, true)
    end)
  end)
  T(ok, string.format("[c tw=%d] desenho não lança erro", tw))

  if ok then
    local n = 0
    for _, ln in ipairs(linhas(out)) do if ln ~= "" then n = n + 1 end end
    T(n <= 27, string.format("[c tw=%d] card cabe em th=27 (linhas=%d)", tw, n))

    local ruim = nil
    for k in out:gmatch("\27%[(%d+)A") do
      if tonumber(k) ~= 1 then ruim = k end
    end
    T(ruim == nil, string.format("[c tw=%d] toda volta de cursor é de 1 linha", tw))

    local em = emulador.novo(tw, 27)
    local ok2 = pcall(function() em.feed(out) end)
    T(ok2, string.format("[c tw=%d] emulador pinta sem erro", tw))
  end
end

core.tw, core.th = orig_tw, orig_th
print(string.format("\n%d falha(s)", failures))
print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
