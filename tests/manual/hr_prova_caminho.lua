-- tests/manual/hr_prova_caminho.lua — prova no CAMINHO REAL do renderizador (#324).
-- Ao vivo: rode sob um PTY; core.tw() lê o tamanho real do terminal via stty.
-- Replay: passe um arquivo .md gravado como argumento para reprocessá-lo.
-- Não é uma spec (vive em tests/manual/, fora do glob tests/*.lua do CI).
package.path = "./?.lua;./?/init.lua;./lib/?.lua;" .. package.path

local core     = require("ui.core")
local renderer = require("renderer")

local TEXT = "Resumo da resposta.\n\n---\n\nFim do relatório."

-- arg[1]: se apontar para um arquivo existente, usa como texto (replay de gravação).
local src  = arg and arg[1]
local text = TEXT
if src then
  local f = io.open(src, "r")
  if f then text = f:read("*a"); f:close() end
end

local function strip(s) return (s:gsub("\27%[[0-9;]*m", "")) end

local raw = renderer.render(text)
print("TW=" .. tostring(core.tw()))
for ln in (raw .. "\n"):gmatch("([^\n]*)\n") do
  local n = select(2, strip(ln):gsub("─", ""))
  if n > 0 then print("HR_LARGURA=" .. n) end
end
