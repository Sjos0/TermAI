-- ui/spinner/rotulo.lua — Liga a máquina de estados (fase.lua) ao spinner e à região de rolagem.
-- Escreve em TMPDIR: termai_frames.txt (1ª linha = nº de quadros, depois um quadro por linha) e
-- termai_rows.txt (altura da tela, só enquanto a região está ativa). O spinner sh lê os dois.
local fase    = require("ui.spinner.fase")
local shimmer = require("ui.spinner.shimmer")
local region  = require("ui.status_region")

local M = {}

local TMPDIR      = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
local FRAMES_FILE = TMPDIR .. "/termai_frames.txt"
local ROWS_FILE   = TMPDIR .. "/termai_rows.txt"

local estado = fase.new()
local rows_ativas = nil

local function escreve_quadros(rotulo)
  local quadros = shimmer.frames(rotulo)
  local f = io.open(FRAMES_FILE, "w")
  if not f then return end
  f:write(tostring(#quadros), "\n")
  for _, q in ipairs(quadros) do f:write(q, "\n") end
  f:close()
end

local function altura_tela()
  local h = io.popen("stty size 2>/dev/null")
  if not h then return 0 end
  local rows = tonumber(h:read("*n") or "")
  h:close()
  return rows or 0
end

local function ativa_regiao()
  if rows_ativas then return end
  local rows = altura_tela()
  if rows < 5 then return end
  rows_ativas = rows
  io.write(region.setup(rows))
  local f = io.open(ROWS_FILE, "w")
  if f then f:write(tostring(rows)); f:close() end
  io.flush()
end

local function desativa_regiao()
  if not rows_ativas then return end
  io.write(region.teardown(rows_ativas))
  io.flush()
  rows_ativas = nil
  os.remove(ROWS_FILE)
end

-- Evento vindo do fluxo do agente/usuário. Devolve o estado novo.
function M.evento(nome)
  local novo = fase.on(estado, nome)
  if novo == estado then return estado end
  estado = novo
  if nome == "user_send" then ativa_regiao() end
  local rotulo = fase.label(estado)
  if rotulo then
    escreve_quadros(rotulo)
  else
    os.remove(FRAMES_FILE)
    desativa_regiao()
  end
  return estado
end

function M.estado() return estado end

-- Só para testes: volta ao ocioso e limpa arquivos.
function M.reset()
  estado = fase.new()
  os.remove(FRAMES_FILE)
  desativa_regiao()
end

return M
