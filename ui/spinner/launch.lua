-- ui/spinner/launch.lua — scripts shell embutidos + start/kill do spinner.
local M = {}

local TMPDIR          = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
local _spin_sh        = TMPDIR .. "/ta_spin.sh"
local _spin_pid       = TMPDIR .. "/ta_pid"
local _inject_flag    = TMPDIR .. "/ta_inject.flag"
local _reasoning_flag = TMPDIR .. "/ta_reasoning.flag"
local _stream_flag    = TMPDIR .. "/termai_stream.flag"

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
  printf '\r%s %s%s%s %s(%ds)%s  \033[K' "$f" "${B}${LB}" "$LABEL" "$R" "$D" "$s" "$R"
  sleep 0.1
  c=$((c + 1))
  if [ $((c % 10)) -eq 0 ]; then s=$((s + 1)); fi
  i=$(( (i + 1) % 6 ))
done
]]

local COMPACT_SCRIPT = [[
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
F0="${D}[${R}${C1}=${R}${D}   ]${R}"
F1="${D}[${R}${C1}=${C2}=${R}${D}  ]${R}"
F2="${D}[${R}${C1}=${C2}=${C3}=${R}${D} ]${R}"
F3="${D}[${R}${D} ${R}${C2}=${C3}=${C4}=${R}${D}]${R}"
F4="${D}[${R}${D}  ${R}${C3}=${C4}=${R}${D}]${R}"
F5="${D}[${R}${D}   ${R}${C4}=${R}${D}]${R}"

LBLUE="${ESC}[38;5;117m"
YELLOW="${ESC}[38;5;220m"

INJECT_FLAG="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/ta_inject.flag"
REASONING_FLAG="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/ta_reasoning.flag"
if [ -f "$INJECT_FLAG" ]; then
  LABEL="Requisitando"
  INJECT_DONE=1
else
  LABEL="Injetando"
  INJECT_DONE=0
fi
REASONING_DONE=0

c=0
while true
do
  if [ "$INJECT_DONE" -eq 0 ] && [ -f "$INJECT_FLAG" ]; then
    INJECT_DONE=1
    LABEL="Requisitando"
  fi
  if [ "$REASONING_DONE" -eq 0 ] && [ -f "$REASONING_FLAG" ]; then
    REASONING_DONE=1
    LABEL="Pensando"
    pc=0
  fi

  case $((c % 6)) in
    0) f="$F0" ;;
    1) f="$F1" ;;
    2) f="$F2" ;;
    3) f="$F3" ;;
    4) f="$F4" ;;
    5) f="$F5" ;;
  esac

  if [ "$REASONING_DONE" -eq 1 ]; then
    ms_val=$((pc * 100))
    if [ "$ms_val" -lt 1000 ]; then
      TIMER="${ms_val}ms"
    elif [ "$ms_val" -lt 60000 ]; then
      sec_val=$((ms_val / 1000))
      dec_val=$(((ms_val % 1000) / 100))
      if [ "$dec_val" -eq 0 ]; then
        TIMER="${sec_val}seg"
      else
        TIMER="${sec_val}.${dec_val}seg"
      fi
    else
      min_val=$((ms_val / 60000))
      sec_val=$(((ms_val % 60000) / 1000))
      TIMER="${min_val}min ${sec_val}seg"
    fi
    printf '\r%s %s%s%s %s(%s)%s  \033[K' "$f" "${LBLUE}" "$LABEL" "${R}" "${YELLOW}" "${TIMER}" "${R}"
    pc=$((pc + 1))
  else
    printf '\r%s %s%s%s  \033[K' "$f" "${LBLUE}" "$LABEL" "${R}"
  fi
  sleep 0.1
  c=$((c + 1))
done
]]

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
  io.write("\r\27[K")
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
