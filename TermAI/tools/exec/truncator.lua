-- tools/exec/truncator.lua — Truncamento de output (tail).
-- Função pura: recebe string cru, retorna string truncada.
-- Separação de responsabilidade: quem executa NÃO trunca, quem trunca NÃO executa.
local constants = require("tools.exec.constants")

local M = {}

-- Trunca res para as últimas MAX_BYTES bytes OU MAX_LINES linhas (o que ocorrer primeiro).
-- Preserva comportamento idêntico ao v3 inline.
function M.truncate_tail(res)
  local MAX_BYTES = constants.MAX_BYTES
  local MAX_LINES = constants.MAX_LINES

  -- Caminho 1: excede bytes → pega tail por bytes
  if #res > MAX_BYTES then
    local tail = res:sub(-MAX_BYTES)
    local nl   = tail:find("\n") or 0
    return "...[truncado — últimos " .. MAX_BYTES
           .. "B de " .. #res .. "B]\n" .. tail:sub(nl + 1)
  end

  -- Caminho 2: conta linhas
  local n = 0
  for _ in res:gmatch("\n") do n = n + 1 end
  if n <= MAX_LINES then return res end

  -- Caminho 3: excede linhas → pega tail por linhas
  local skip, pos = n - MAX_LINES, 1
  for _ = 1, skip do pos = (res:find("\n", pos, true) or #res) + 1 end
  return "...[" .. n .. " linhas — mostrando últimas " .. MAX_LINES .. "]\n" .. res:sub(pos)
end

return M
