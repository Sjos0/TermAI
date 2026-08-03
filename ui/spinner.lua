local core = require("ui.core")
local c = core.c
local M = {}

local TMPDIR          = os.getenv("TMPDIR") or "/data/data/com.termux/files/usr/tmp"
local _spin_sh        = TMPDIR .. "/ta_spin.sh"
local _spin_pid       = TMPDIR .. "/ta_pid"
local _inject_flag    = TMPDIR .. "/ta_inject.flag"
local _reasoning_flag = TMPDIR .. "/ta_reasoning.flag"
local _stream_flag    = TMPDIR .. "/termai_stream.flag"
local _anim_start         = nil
local _start_ms           = nil
local _reasoning_start_ms = nil
local _retry_lines        = 0

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

local function get_thinking_mode()
  local ok, config_mod = pcall(require, "config")
  if ok and config_mod then
    local ok_val, val = pcall(config_mod.get, "agents.defaults.thinking_mode")
    if ok_val and val then
      return val
    end
  end
  return "expanded"
end

local function get_ms_time()
  local f = io.popen("date +%s%3N")
  if f then
    local s = f:read("*l")
    f:close()
    local val = tonumber(s)
    if val then return val end
  end
  return os.time() * 1000
end

local function format_duration(ms)
  if ms < 1000 then
    return string.format("%dms", ms)
  elseif ms < 60000 then
    local sec = ms / 1000
    local integer, fractional = math.modf(sec)
    if fractional >= 0.1 then
      return string.format("%.1fseg", sec)
    else
      return string.format("%dseg", integer)
    end
  else
    local total_sec = math.floor(ms / 1000)
    local min = math.floor(total_sec / 60)
    local sec = total_sec % 60
    if sec > 0 then
      return string.format("%dmin %dseg", min, sec)
    else
      return string.format("%dmin", min)
    end
  end
end

local function _launch()
  local f = io.open(_spin_sh, "w")
  if not f then return end
  f:write(SPINNER_SCRIPT)
  f:close()
  os.execute("sh " .. _spin_sh .. " 2>/dev/null & echo $! > " .. _spin_pid)
  io.flush()
end

local function _launch_compact()
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
    printf '\r%s %s%s%s %s(%s)%s\033[K' "$f" "${LBLUE}" "$LABEL" "${R}" "${YELLOW}" "${TIMER}" "${R}"
    pc=$((pc + 1))
  else
    printf '\r%s %s%s%s\033[K' "$f" "${LBLUE}" "$LABEL" "${R}"
  fi
  sleep 0.1
  c=$((c + 1))
done
]]

  local f = io.open(_spin_sh, "w")
  if not f then return end
  f:write(COMPACT_SCRIPT)
  f:close()
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
    .. " " .. _inject_flag .. " " .. _reasoning_flag .. " " .. _stream_flag .. " 2>/dev/null")
  io.write("\r\27[K")
  io.flush()
end

function M.start_thinking(label)
  M.kill_spinner()
  M.clear_retry_lines()
  _anim_start         = os.time()
  _start_ms           = get_ms_time()
  _reasoning_start_ms = nil
  _retry_lines        = 0

  local ok_state, state = pcall(require, "ui.stream.state")
  if ok_state and state and state._s then
    state._s.compact_thinking_stopped = false
  end

  if label ~= "Injetando" then
    local f = io.open(_inject_flag, "w")
    if f then f:write("1"); f:close() end
  end

  local tmode = get_thinking_mode()
  if tmode == "compact" then
    _launch_compact()
  else
    _launch()
  end
end

function M.update_label()
  local f = io.open(_inject_flag, "w")
  if f then f:write("1"); f:close() end
end

-- Sinaliza ao spinner compacto que o primeiro token de reasoning chegou,
-- disparando a troca de rótulo "Requisitando" -> "Pensando" no script sh.
function M.mark_reasoning_started()
  _reasoning_start_ms = get_ms_time()
  local f = io.open(_reasoning_flag, "w")
  if f then f:write("1"); f:close() end
end

function M.restart_spinner()
  M.kill_spinner()
  local f = io.open(_inject_flag, "w")
  if f then f:write("1"); f:close() end

  local tmode = get_thinking_mode()
  if tmode == "compact" then
    _launch_compact()
  else
    _launch()
  end
end

function M.stop_thinking_and_print_compact()
  if not _anim_start then return end
  -- Base do cálculo: início do reasoning (o que o usuário viu contar na tela).
  -- Se não houve reasoning nesta resposta, cai pro início do ciclo (Injetando).
  local base_ms = _reasoning_start_ms or _start_ms or get_ms_time()
  local elapsed_ms = get_ms_time() - base_ms
  M.kill_spinner()
  _anim_start = nil

  local LBLUE = "\27[38;5;117m"
  local YELLOW = "\27[38;5;220m"
  local RESET = "\27[0m"
  -- Patch GLM 5.2 (2026-08-03): só exibe "Pensou" se houve reasoning real.
  -- Se _reasoning_start_ms é nil, nenhum token de reasoning chegou — limpa
  -- spinner silenciosamente e pula pra resposta.
  if _reasoning_start_ms then
    io.write("\r\27[K" .. LBLUE .. "⬤ " .. "Pensou " .. RESET .. YELLOW .. "(" .. format_duration(elapsed_ms) .. ")" .. RESET .. "\n\n")
  else
    io.write("\r\27[K\n")
  end
  io.flush()
end

function M.stop_thinking()
  local tmode = get_thinking_mode()
  if tmode == "compact" then
    local ok_state, state = pcall(require, "ui.stream.state")
    if ok_state and state and state._s then
      if not state._s.compact_thinking_stopped then
        state._s.compact_thinking_stopped = true
        M.stop_thinking_and_print_compact()
      end
    else
      M.stop_thinking_and_print_compact()
    end
    local elapsed = os.time() - (_anim_start or os.time())
    _anim_start = nil
    return elapsed
  else
    local elapsed = os.time() - (_anim_start or os.time())
    M.kill_spinner()
    _anim_start = nil
    return elapsed
  end
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
