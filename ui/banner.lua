-- ui/banner.lua — Componente reutilizável do banner TermAI (assets/banner.txt).
-- Gradiente azul linha por linha em truecolor. Usado pela TUI (ui/header.lua) e pela CLI
-- (main.lua), para que o banner tenha a mesma cara em qualquer lugar. Função pura: não escreve na tela.
local M = {}

M.RESET = "\27[0m"
M.BOLD  = "\27[1m"

-- Lê as linhas do banner. Devolve a lista e a maior largura (em caracteres).
function M.read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local lines, max_w = {}, 0
  for line in f:lines() do
    line = line:gsub("\r$", "")
    lines[#lines + 1] = line
    local w = utf8.len(line) or #line
    if w > max_w then max_w = w end
  end
  f:close()
  return lines, max_w
end

-- Cor da linha i de n: do azul claro (60,180,255) ao azul escuro (0,40,150).
function M.color_for(i, n)
  local ratio = (n > 1) and ((i - 1) / (n - 1)) or 0
  local r = math.floor(60  + (0   - 60)  * ratio)
  local g = math.floor(180 + (40  - 180) * ratio)
  local b = math.floor(255 + (150 - 255) * ratio)
  return string.format("\27[38;2;%d;%d;%dm", r, g, b)
end

-- Banner colorido como texto único, pronto para io.write (usado pela CLI).
-- Se o arquivo não existir, devolve nil (quem chama decide o que mostrar).
function M.render(path)
  local lines = M.read(path)
  if not lines then return nil end
  local out = {}
  for i, line in ipairs(lines) do
    out[#out + 1] = M.color_for(i, #lines) .. M.BOLD .. line .. M.RESET
  end
  return table.concat(out, "\n")
end

return M
