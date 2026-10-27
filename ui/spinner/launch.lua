-- ui/spinner/launch.lua — scripts shell embutidos + start/kill do spinner.
local M = {}

local TMPDIR          = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
local _spin_sh        = TMPDIR .. "/ta_spin.sh"
local _spin_pid       = TMPDIR .. "/ta_pid"
local _inject_flag    = TMPDIR .. "/ta_inject.flag"
local _reasoning_flag = TMPDIR .. "/ta_reasoning.flag"
local _stream_flag    = TMPDIR .. "/termai_stream.flag"

local roteiros = require("ui.spinner.roteiros")
local SPINNER_SCRIPT, COMPACT_SCRIPT = roteiros.SPINNER_SCRIPT, roteiros.COMPACT_SCRIPT

local function _write_and_launch(script)
  local f = io.open(_spin_sh, "w")
  if not f then return end
  f:write(script)
  f:close()
  os.execute("sh " .. _spin_sh .. " 2>/dev/null & echo $! > " .. _spin_pid)
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

--- Mata o processo do spinner e limpa arquivos temporários/flags.
function M.kill_spinner()
  local pid_f = io.open(_spin_pid, "r")
  if not pid_f then return end
  local pid = pid_f:read("*l")
  pid_f:close()
  if pid and pid:match("^%d+$") then
    os.execute("kill " .. pid .. " 2>/dev/null")
  end
  os.execute("rm -f " .. _spin_pid .. " " .. _spin_sh
    .. " " .. _inject_flag .. " " .. _reasoning_flag .. " " .. _stream_flag .. " 2>/dev/null")
  -- Com a região de rolagem ativa, a status line é a última linha: limpa ela, não a linha atual (#176 P3).
  local rf = io.open(TMPDIR .. "/termai_rows.txt", "r")
  local rows = rf and tonumber(rf:read("*l") or "") or nil
  if rf then rf:close() end
  if rows and rows >= 5 then
    io.write("\27" .. "7\27[" .. rows .. ";1H\r\27[2K\27" .. "8")
  else
    io.write("\r\27[K")
  end
  io.flush()
end

--- Sinaliza que a injeção terminou (troca label Injetando → Requisitando).
function M.set_inject_flag()
  local f = io.open(_inject_flag, "w")
  if f then f:write("1"); f:close() end
end

--- Sinaliza ao spinner compacto que o reasoning começou.
function M.set_reasoning_flag()
  local f = io.open(_reasoning_flag, "w")
  if f then f:write("1"); f:close() end
end

return M
