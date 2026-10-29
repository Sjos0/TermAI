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

-- HOTFIX: modo região desligado. Posição absoluta do spinner quebrava com teclado/rotação (#hotfix).
local REGIAO_ATIVA = false

-- Cache da altura da tela (perf #185): revalidado a cada segundo.
local _altura_cache = nil
local _altura_cache_sec = nil

local function escreve_quadros(rotulo)
  local quadros = shimmer.frames(rotulo)
  local tmp = FRAMES_FILE .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(tostring(#quadros), "\n")
local function altura_tela()
  -- Cache com revalidação espaçada: dentro do mesmo segundo reutiliza a altura
  -- lida, evitando spawnar `stty size` a cada chamada (perf #185).
  local agora = os.time()
  if _altura_cache and _altura_cache_sec == agora then
    return _altura_cache
  end
  local h = io.popen("stty size 2>/dev/null")
  if not h then return 0 end
  local rows = tonumber(h:read("*n") or "")
  h:close()
  _altura_cache = rows or 0
  _altura_cache_sec = agora
  return _altura_cache
end
  if not h then return 0 end
  local rows = tonumber(h:read("*n") or "")
  h:close()
  return rows or 0
end

local function ativa_regiao()
  if not REGIAO_ATIVA or rows_ativas then return end
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
-- Refaz a região se a altura da tela mudou (rotação do celular) desde a última vez.
local function reajusta_regiao()
  if not rows_ativas then return end
  local agora = altura_tela()
  if agora >= 5 and agora ~= rows_ativas then
    io.write(region.teardown(rows_ativas))
    rows_ativas = nil
    ativa_regiao()
  end
end

function M.evento(nome)
  local novo = fase.on(estado, nome)
  if novo == estado then return estado end
  estado = novo
  if nome == "user_send" then ativa_regiao() end
  reajusta_regiao()
  local rotulo = fase.label(estado)
  if rotulo then
    escreve_quadros(rotulo)
  else
    os.remove(FRAMES_FILE)
    desativa_regiao()
    -- Fim do turno: mata sh e limpa flags/frames residual (evita Requisitando em loop).
    pcall(function() require("ui.spinner.launch").cleanup_turno() end)
  end
  return estado
end

function M.estado() return estado end

-- true enquanto o turno está em modo região (spinner fixo na última linha).
function M.regiao_ativa() return rows_ativas ~= nil end

-- Saída normal pelo os.exit também desfaz a região (Ctrl+C não passa por aqui: Lua não captura SIGINT).
local os_exit_original = os.exit
os.exit = function(...)
  pcall(desativa_regiao)
  return os_exit_original(...)
end

-- Só para testes: volta ao ocioso e limpa arquivos.
function M.reset()
  estado = fase.new()
  os.remove(FRAMES_FILE)
  desativa_regiao()
end

return M
