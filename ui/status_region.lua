-- ui/status_region.lua — Sequências ANSI da região de rolagem: a última linha fica fixa (status line),
-- o resto da tela rola acima dela. Função pura: só devolve strings; quem escreve é o chamador.
-- DECSTBM (ESC[t;br) define a faixa que rola. DECSC/DECRC (ESC 7 / ESC 8) salvam e restauram o cursor.
local M = {}

local ESC = "\27"

-- Faixa de rolagem = linhas 1 até rows-1. A última linha fica de fora.
function M.setup(rows)
  if rows < 3 then return "" end
  return ESC .. "[1;" .. (rows - 1) .. "r"
end

-- Desfaz a faixa e deixa o cursor embaixo, limpando a status line.
function M.teardown(rows)
  return ESC .. "[r" .. ESC .. "[" .. rows .. ";1H" .. ESC .. "[2K"
end

-- Escreve o texto na última linha sem mover o cursor do conteúdo.
function M.draw_status(rows, text)
  return ESC .. "7" .. ESC .. "[" .. rows .. ";1H" .. ESC .. "[2K" .. text .. ESC .. "[0m" .. ESC .. "8"
end

return M
