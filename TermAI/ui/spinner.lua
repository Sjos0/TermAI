local core = require("ui.core")
local c = core.c
local M = {}

local TMPDIR       = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
local _spin_sh     = TMPDIR .. "/ta_spin.sh"
local _spin_pid    = TMPDIR .. "/ta_pid"
local _inject_flag = TMPDIR .. "/ta_inject.flag"
local _stream_flag = TMPDIR .. "/termai_stream.flag"
local _anim_start  = nil
local _retry_lines = 0

local SPINNER_SCRIPT = [[
#!/bin/sh
trap 'exit 0' TERM
ESC=$(printf '\033')
R="${ESC}[0m"
B="${ESC}[1m"
D="${ESC}[2m"
C1="${ESC}[38;2;25;60;180m"
C2="${ESC}[38;2;45;110;225m"
C3="${ESC}[38;2;75;155;245m"
C4="${ESC}[38;2;115;200;255m"
LB="${ESC}[38;2;255;193;7m"
F0="${D}[${R}${C1}=${R}${D}   ]${R}"
F1="${D}[${R}${C1}=${C2}=${R}${D}  ]${R}"
F2="${D}[${R}${C1}=${C2}=${C3}=${R}${D} ]${R}"
F3="${D}[${R}${D} ${R}${C2}=${C3}=${C4}=${R}${D}]${R}"
F4="${D}[${R}${D}  ${R}${C3}=${C4}=${R}${D}]${R}"
F5="${D}[${R}${D}   ${R}${C4}=${R}${D}]${R}"
FLAG="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/termai_stream.flag"
INJECT_FLAG="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/ta_inject.flag"
if [ -f "$INJECT_FLAG" ]; then
  LABEL="Requisitando"
  INJECT_DONE=1
else
  LABEL="Injetando"
  INJECT_DONE=0
fi
CONFIRMED=0
i=0
s=0
c=0
while true
do
    if [ "$INJECT_DONE" -eq 0 ] && [ -f "$INJECT_FLAG" ]; then
      INJECT_DONE=1
      LABEL="Requisitando"
    fi
    if [ "$CONFIRMED" -eq 0 ] && [ -f "$FLAG" ]; then
      CONFIRMED=1
      LB="${ESC}[38;2;115;200;255m"
    fi
  case $i in
    0) f="$F0" ;;
    1) f="$F1" ;;
    2) f="$F2" ;;
    3) f="$F3" ;;
    4) f="$F4" ;;
    5) f="$F5" ;;
  esac
  printf '\r%s %s%s%s %s(%ds)%s\033[K' "$f" "${B}${LB}" "$LABEL" "$R" "$D" "$s" "$R"
  sleep 0.1
  c=$((c + 1))
  if [ $((c % 10)) -eq 0 ]; then s=$((s + 1)); fi
  i=$(( (i + 1) % 6 ))
done
]]

local function _launch()
  local f = io.open(_spin_sh, "w")
  if not f then return end
  f:write(SPINNER_SCRIPT)
  f:close()
  -- 2>/dev/null no sh captura erros de sintaxe do script sem vazarem pro terminal
  os.execute("sh " .. _spin_sh .. " 2>/dev/null & echo $! > " .. _spin_pid)
  io.flush()
end

function M.kill_spinner()
  local pid_f = io.open(_spin_pid, "r")
  if not pid_f then return end
  local pid = pid_f:read("*l")
  pid_f:close()
  if pid and pid:match("^%d+$") then
    os.execute("kill " .. pid .. " 2>/dev/null")
  end
  os.execute("rm -f " .. _spin_pid .. " " .. _spin_sh
    .. " " .. _inject_flag .. " " .. _stream_flag .. " 2>/dev/null")
  io.write("\r\27[K")
  io.flush()
end

-- label: "Injetando" para pre-flight ativo; nil ou outro valor = "Requisitando" direto
function M.start_thinking(label)
  M.kill_spinner()
  M.clear_retry_lines()
  _anim_start  = os.time()
  _retry_lines = 0
  if label ~= "Injetando" then
    local f = io.open(_inject_flag, "w")
    if f then f:write("1"); f:close() end
  end
  _launch()
end

-- Sinaliza ao spinner para transicionar de "Injetando" para "Requisitando"
function M.update_label()
  local f = io.open(_inject_flag, "w")
  if f then f:write("1"); f:close() end
end

function M.restart_spinner()
  M.kill_spinner()
  -- restart ocorre em ciclos de tool call: sempre "Requisitando"
  local f = io.open(_inject_flag, "w")
  if f then f:write("1"); f:close() end
  _launch()
end

function M.stop_thinking()
  local elapsed = os.time() - (_anim_start or os.time())
  M.kill_spinner()
  _anim_start = nil
  return elapsed
end

function M.show_retry(attempt, max, reason, wait)
  local orange = "\27[38;5;208m"
  io.write(orange .. "  ⚠ Tentativa " .. attempt .. "/" .. max
    .. " — " .. reason .. c.reset .. "\n")
  _retry_lines = _retry_lines + 1
  if wait > 0 then
    io.write(c.gray .. "  ⏳ Aguardando " .. wait .. "s..." .. c.reset .. "\n")
    _retry_lines = _retry_lines + 1
  end
  io.flush()
end

function M.clear_retry_lines()
  if _retry_lines > 0 then
    io.write(string.format("\27[%dA\27[J", _retry_lines))
    io.flush()
    _retry_lines = 0
  end
end

return M
