-- ui/spinner/launch.lua — scripts shell embutidos + start/kill do spinner.
local M = {}

local TMPDIR = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
local function _my_pid()
  local f = io.open("/proc/self/stat", "r")
  if not f then return "0" end
  local s = f:read("*l") or ""; f:close()
  return (s:match("^(%d+)") or "0")
end
local PID = _my_pid()
local _spin_sh        = TMPDIR .. "/ta_spin_" .. PID .. ".sh"
local _spin_pid       = TMPDIR .. "/ta_pid_" .. PID
local _inject_flag    = TMPDIR .. "/ta_inject_" .. PID .. ".flag"
local _reasoning_flag = TMPDIR .. "/ta_reasoning_" .. PID .. ".flag"
local _stream_flag    = TMPDIR .. "/termai_stream_" .. PID .. ".flag"
local _frames_file    = TMPDIR .. "/termai_frames_" .. PID .. ".txt"
local _rows_file      = TMPDIR .. "/termai_rows_" .. PID .. ".txt"

local function _pid_alive(pid)
  local f = io.open("/proc/" .. pid .. "/stat", "r")
  if not f then return false end
  local s = f:read("*l") or ""; f:close()
  -- estado Z = zumbi: trata como morto
  local state = s:match("^%d+ %S+ (%S)")
  return state ~= nil and state ~= "Z"
end

local roteiros = require("ui.spinner.roteiros")
local SPINNER_SCRIPT, COMPACT_SCRIPT = roteiros.SPINNER_SCRIPT, roteiros.COMPACT_SCRIPT

local function _is_spinner(pid)
  -- Valida que o processo ainda é o spinner (ta_spin.sh) antes de matar.
  -- Evita matar um pid reutilizado por outro processo após uma morte abrupta.
  local f = io.open("/proc/" .. pid .. "/cmdline", "r")
  if not f then return false end
  local cmdline = f:read("*l") or ""
  f:close()
  return cmdline:find("ta_spin.sh", 1, true) ~= nil
end

local function _kill_pid()
  local pid_f = io.open(_spin_pid, "r")
  if not pid_f then return end
  local pid = pid_f:read("*l")
  pid_f:close()
  if not (pid and pid:match("^%d+$")) then return end
  if not _is_spinner(pid) then
    os.remove(_spin_pid)
    return
  end
  -- TERM no processo e no grupo; KILL se ainda vivo.
  os.execute("kill -TERM " .. pid .. " 2>/dev/null; kill -TERM -" .. pid .. " 2>/dev/null")
  os.execute("kill -KILL " .. pid .. " 2>/dev/null; kill -KILL -" .. pid .. " 2>/dev/null")
  os.remove(_spin_pid)
end

local function _write_and_launch(script)
  _kill_pid()
  local f = io.open(_spin_sh, "w")
  if not f then return end
  f:write(script)
  f:close()
  os.execute("sh -c 'sh \"" .. _spin_sh .. "\" 2>/dev/null & echo $! > \"" .. _spin_pid .. "\"'")
  io.flush()
end

--- Lança o spinner no modo expanded (com contador de segundos).
function M.launch()
  _write_and_launch(SPINNER_SCRIPT)
end

--- Lança o spinner no modo compact (com timer de reasoning).
function M.launch_compact()
  _write_and_launch(COMPACT_SCRIPT)
end

--- Para o processo do spinner e limpa a linha atual.
-- Não apaga termai_frames.txt: no meio do turno o rótulo (Trabalhando) precisa sobreviver
-- a um stop/start entre tool calls. Quem apaga os frames é o turn_end (rotulo) / cleanup_turno.
function M.kill_spinner()
  _kill_pid()
  os.remove(_spin_sh)
  os.remove(TMPDIR .. "/ta_tool_draw.flag")
  os.remove(_stream_flag)
  -- Hotfix: só \r + limpa linha. Nunca posição absoluta (arquivo de altura fica velho no teclado).
  io.write("\r\27[K")
  io.flush()
end

--- Limpeza completa no fim do turno: flags, frames e rows residual.
function M.cleanup_turno()
  _kill_pid()
  os.execute("rm -f " .. _spin_pid .. " " .. _spin_sh
    .. " " .. _inject_flag .. " " .. _reasoning_flag .. " " .. _stream_flag
    .. " " .. _frames_file .. " " .. _rows_file
    .. " " .. TMPDIR .. "/ta_tool_draw.flag 2>/dev/null")
  io.write("\r\27[K")
  io.flush()
end

--- Limpeza no início do TUI: mata spinner órfão de execuções anteriores (validando
--- que o processo ainda é o spinner) e remove flags/payloads residuais em $TMPDIR.
function M.cleanup_startup()
  require("ui.spinner.cleanup_startup").run(TMPDIR)
end

--- Sinaliza que a injeção terminou (troca label Injetando → Requisitando).
function M.set_inject_flag()
  local f = io.open(_inject_flag, "w")
  if f then f:write("1"); f:close() end
end

--- Remove a flag de reasoning (início de uma nova resposta no mesmo turno).
function M.clear_reasoning_flag()
  os.remove(_reasoning_flag)
end

--- Sinaliza ao spinner compacto que o reasoning começou.
function M.set_reasoning_flag()
  local f = io.open(_reasoning_flag, "w")
  if f then f:write("1"); f:close() end
end

return M
