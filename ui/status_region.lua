-- ui/status_region.lua — Sequências ANSI da região de rolagem: a última linha fica fixa (status line),
-- o resto da tela rola acima dela. Função pura: só devolve strings; quem escreve é o chamador.
-- DECSTBM (ESC[t;br) define a faixa que rola. DECSC/DECRC (ESC 7 / ESC 8) salvam e restauram o cursor.
local M = {}

local ESC = "\27"

-- Faixa de rolagem = linhas 1 até rows-1. A última linha fica de fora.
-- DECSTBM leva o cursor ao topo: salvamos e restauramos a posição do conteúdo em volta dele.
function M.setup(rows)
  if rows < 3 then return "" end
  return ESC .. "7" .. ESC .. "[1;" .. (rows - 1) .. "r" .. ESC .. "8"
end

-- Desfaz a faixa e deixa o cursor embaixo, limpando a status line.
-- Limpa a status line e solta a faixa, sempre devolvendo o cursor ao conteúdo.
function M.teardown(rows)
  return ESC .. "7" .. ESC .. "[" .. rows .. ";1H" .. ESC .. "[2K" .. ESC .. "8"
      .. ESC .. "7" .. ESC .. "[r" .. ESC .. "8"
end

-- Escreve o texto na última linha sem mover o cursor do conteúdo.
function M.draw_status(rows, text)
  return ESC .. "7" .. ESC .. "[" .. rows .. ";1H" .. ESC .. "[2K" .. text .. ESC .. "[0m" .. ESC .. "8"
end

return M
