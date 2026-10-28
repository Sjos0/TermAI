-- ui/spinner/roteiros.lua — scripts shell do spinner (modo expanded e compact), usados por ui/spinner/launch.lua.
local SPINNER_SCRIPT = [[
#!/bin/sh
trap 'exit 0' TERM
ESC=$(printf '\033')
FRAMES="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/termai_frames.txt"
ROWS_F="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/termai_rows.txt"
# pick_frame N: lê FRAMES (1ª linha = total) e põe em FRAME o quadro N % total.
pick_frame() {
  FRAME=""; tot=0; n=0
  while IFS= read -r fl; do
    if [ "$n" -eq 0 ]; then tot="$fl"; n=1; continue; fi
    if [ "$tot" -gt 0 ] && [ $((n-1)) -eq $(( $1 % tot )) ]; then FRAME="$fl"; fi
    n=$((n+1))
  done < "$FRAMES"
  if [ -z "$FRAME" ]; then FRAME="$LABEL"; fi
}
# show_line TEXTO_COLORIDO: desenha na última linha da região (se houver) ou na linha atual.
show_line() {
  if [ -f "$ROWS_F" ]; then
    R_ROWS=$(cat "$ROWS_F" 2>/dev/null)
    printf '%s7%s[%s;1H\r%s%s[K%s8' "$ESC" "$ESC" "$R_ROWS" "$1" "$ESC" "$ESC"
  else
    printf '\r%s\033[K' "$1"
  fi
}
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
  if [ -f "$FRAMES" ]; then
    pick_frame "$c"
    show_line "$f $FRAME ${D}(${s}s)${R}  "
  else
    printf '\r%s %s%s%s %s(%ds)%s  \033[K' "$f" "${B}${LB}" "$LABEL" "$R" "$D" "$s" "$R"
  fi
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
FRAMES="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/termai_frames.txt"
ROWS_F="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/termai_rows.txt"
# pick_frame N: lê FRAMES (1ª linha = total) e põe em FRAME o quadro N % total.
pick_frame() {
  FRAME=""; tot=0; n=0
  while IFS= read -r fl; do
    if [ "$n" -eq 0 ]; then tot="$fl"; n=1; continue; fi
    if [ "$tot" -gt 0 ] && [ $((n-1)) -eq $(( $1 % tot )) ]; then FRAME="$fl"; fi
    n=$((n+1))
  done < "$FRAMES"
  if [ -z "$FRAME" ]; then FRAME="$LABEL"; fi
}
# show_line TEXTO_COLORIDO: desenha na última linha da região (se houver) ou na linha atual.
show_line() {
  if [ -f "$ROWS_F" ]; then
    R_ROWS=$(cat "$ROWS_F" 2>/dev/null)
    printf '%s7%s[%s;1H\r%s%s[K%s8' "$ESC" "$ESC" "$R_ROWS" "$1" "$ESC" "$ESC"
  else
    printf '\r%s\033[K' "$1"
  fi
}
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
  if [ -f "$REASONING_FLAG" ]; then
    if [ "$REASONING_DONE" -eq 0 ]; then REASONING_DONE=1; pc=0; fi
  else
    REASONING_DONE=0
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
    show_line "$f ${LBLUE}Pensando${R} ${YELLOW}(${TIMER})${R}  "
    pc=$((pc + 1))
  else
    if [ -f "$FRAMES" ]; then
      pick_frame "$c"
      show_line "$f $FRAME  "
    else
      printf '\r%s %s%s%s  \033[K' "$f" "${LBLUE}" "$LABEL" "${R}"
    fi
  fi
  sleep 0.1
  c=$((c + 1))
done
]]

return { SPINNER_SCRIPT = SPINNER_SCRIPT, COMPACT_SCRIPT = COMPACT_SCRIPT }
