-- ui/spinner/shimmer.lua — Brilho que atravessa o texto (estilo Codex) para os rótulos do spinner.
-- Função pura: gera uma lista de quadros já coloridos. Quem desenha é o spinner (sh) ou a status line.
local M = {}

local BASE      = 214   -- laranja
local HIGHLIGHT = 226   -- amarelo claro
local PAD       = 3     -- colunas de folga antes/depois do texto, para a faixa entrar e sair
local HALF_W    = 2     -- meia largura da faixa de brilho, em caracteres

local function chars_of(s)
  local t = {}
  for _, cp in utf8.codes(s) do t[#t + 1] = utf8.char(cp) end
  return t
end

-- Intensidade 0..1 de cada posição, com faixa cossenoidal centrada em `center`.
local function intensity(i, center)
  local d = math.abs(i - center)
  if d > HALF_W then return 0 end
  return 0.5 + 0.5 * math.cos(math.pi * d / (HALF_W + 1))
end

-- Devolve uma lista de quadros (um por passo). O ciclo completo tem #texto + 2*PAD quadros.
function M.frames(text)
  local cs = chars_of(text)
  local n = #cs + 2 * PAD
  local out = {}
  for k = 0, n - 1 do
    local center = k + 1               -- posição da faixa no eixo do texto + folga
    local buf = {}
    for i, ch in ipairs(cs) do
      local pos = i + PAD
      local t = intensity(pos, center)
      local code = BASE + math.floor((HIGHLIGHT - BASE) * t + 0.5)
      buf[#buf + 1] = string.format("\27[38;5;%dm%s", code, ch)
    end
    buf[#buf + 1] = "\27[0m"
    out[#out + 1] = table.concat(buf)
  end
  return out
end

-- Texto sem cor (terminal sem 256 cores).
function M.plain(text)
  return text
end

return M
