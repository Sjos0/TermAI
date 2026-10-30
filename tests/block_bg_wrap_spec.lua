-- tests/block_bg_wrap_spec.lua — #269: Block com bg preenchido + quebra por palavra.
-- Emulador/medição independente: não importa ui/widgets/* para medir SGR/fundo.
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local failures = 0
local function T(cond, msg)
  if cond then print("OK:   " .. msg) else failures = failures + 1; print("FAIL: " .. msg) end
end

local block = require("ui.widgets.block")
local largura = require("ui.largura")

local function plain(s)
  return (s or ""):gsub("\27%[[0-9;:?]*[A-Za-z]", "")
end
local function vis(s) return largura.colunas(plain(s)) end

-- Critério 1: bg cobre TODA a largura de cada linha (SGR de fundo presente e
-- células preenchidas; medimos presença de bg SGR e largura visual == w).
do
  local BG = "\27[48;5;52m"
  local FG = "\27[38;5;255m"
  local b = block.new({
    borders = block.BORDERS.ALL,
    border_type = block.TYPE.PLAIN,
    border_color = "\27[38;5;203m",
    bg = BG,
    fg = FG,
    content_lines = { "erro curto" },
  })
  local lines = b:render({ w = 40, h = 3 })
  T(#lines == 3, "bg h=3 -> 3 linhas (got " .. #lines .. ")")
  local all_have_bg = true
  for i, ln in ipairs(lines) do
    if not ln:find("48;5;52", 1, true) then all_have_bg = false end
    T(vis(ln) == 40, "linha " .. i .. " largura visual 40 (got " .. vis(ln) .. ")")
  end
  T(all_have_bg, "todas as linhas carregam SGR de fundo bg_error")
end

-- Critério 2: texto longo quebra por palavra (h=nil calcula altura)
do
  local long = "Falha após 5 tentativas — HTTP 500: upstream timeout gateway nao respondeu dentro do limite de 30s e o detalhe continua aqui para forcar wrap"
  local b = block.new({
    borders = block.BORDERS.ALL,
    bg = "\27[48;5;52m",
    fg = "\27[38;5;255m",
    content_lines = { long },
  })
  -- h = nil deve calcular altura pelo conteúdo quebrado
  local lines = b:render({ w = 40, h = nil })
  T(#lines >= 4, "h=nil com texto longo -> altura >= 4 (got " .. #lines .. ")")
  local body_count = 0
  for i = 2, #lines - 1 do
    body_count = body_count + 1
    T(vis(lines[i]) == 40, "corpo linha " .. i .. " largura 40")
  end
  T(body_count >= 2, "texto longo gerou >=2 linhas de corpo (got " .. body_count .. ")")
  -- nenhuma palavra cortada no meio se couber: procura espaços preservados
  local joined = ""
  for i = 2, #lines - 1 do joined = joined .. plain(lines[i]) end
  T(joined:find("timeout", 1, true) ~= nil, "palavra 'timeout' intacta apos wrap")
end

-- Critério 3: palavra sem espaço maior que inner.w quebra por caractere visível
do
  local huge = string.rep("A", 80)
  local b = block.new({
    borders = block.BORDERS.ALL,
    content_lines = { huge },
  })
  local lines = b:render({ w = 20, h = nil })
  T(#lines >= 5, "palavra longa quebra em varias linhas (got " .. #lines .. ")")
  for i, ln in ipairs(lines) do
    T(vis(ln) == 20, "palavra longa linha " .. i .. " w=20")
  end
end

-- Critério 4: regressão — chamadas sem bg/fg produzem mesma forma (3 linhas, bordas)
do
  local b = block.new({ borders = block.BORDERS.ALL, border_type = block.TYPE.PLAIN })
  local lines = b:render({ w = 30, h = 3 })
  T(#lines == 3 and vis(lines[1]) == 30, "regressao sem bg: 3x30")
  local p = plain(lines[1])
  T(p:find("┌", 1, true) and p:find("┐", 1, true), "regressao cantos PLAIN")
end

-- Critério 5: sensibilidade base — se bg sumir de uma linha de borda, falha
-- (este spec já exige all_have_bg; o teste de sensibilidade reintroduz o bug)

print(failures == 0 and "ALL OK" or ("FAILURES: " .. failures))
os.exit(failures == 0 and 0 or 1)
