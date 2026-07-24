#!/bin/sh
# timeout_wrapper.sh — Wrapper de timeout para curl
# Uso: timeout_wrapper.sh MAX_TIME WAIT ENDPOINT AUTH_STYLE API_KEY TMP_PATH
#   MAX_TIME   = timeout total (curl --max-time)
#   WAIT       = segundos sem dados antes de cancelar
#   ENDPOINT   = URL da API
#   AUTH_STYLE = estilo de auth: bearer, x-goog-api-key, ou vazio
#   API_KEY    = chave de API bruta (sem -H, sem aspas), ou vazio
#   TMP_PATH   = arquivo JSON do payload

MAX_TIME="$1"
WAIT="$2"
ENDPOINT="$3"
AUTH_STYLE="$4"
API_KEY="$5"
TMP_PATH="$6"

TMPDIR="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
mkdir -p "$TMPDIR" 2>/dev/null
OUTFILE="$TMPDIR/ta_curl_out_$$"
PIDFILE="$TMPDIR/ta_curl_pid_$$"

# Constroi o header de auth a partir de valores limpos (sem quoting hell)
CURL_AUTH=""
if [ -n "$API_KEY" ]; then
  if [ "$AUTH_STYLE" = "bearer" ]; then
    CURL_AUTH="Authorization: Bearer $API_KEY"
  elif [ "$AUTH_STYLE" = "x-goog-api-key" ]; then
    CURL_AUTH="x-goog-api-key: $API_KEY"
  fi
fi

# Rodar curl em background, escrevendo para OUTFILE
if [ -n "$CURL_AUTH" ]; then
  curl -s -N --max-time "$MAX_TIME" -X POST "$ENDPOINT" \
    -H "$CURL_AUTH" \
    -H "Content-Type: application/json" \
    -d "@$TMP_PATH" > "$OUTFILE" 2>/dev/null &
else
  curl -s -N --max-time "$MAX_TIME" -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "@$TMP_PATH" > "$OUTFILE" 2>/dev/null &
fi
CURL_PID=$!
echo "$CURL_PID" > "$PIDFILE"

# Monitorar: se OUTFILE nao crescer em WAIT segundos, matar
LAST_SIZE=0
FLAG="${TMPDIR:-/data/data/com.termux/files/usr/tmp}/termai_stream.flag"
WAITED=0

while kill -0 "$CURL_PID" 2>/dev/null; do
  sleep 1
  CURRENT_SIZE=$(wc -c < "$OUTFILE" 2>/dev/null || echo 0)

  # Detectar primeiro byte recebido
  if [ "$LAST_SIZE" -eq 0 ] && [ "$CURRENT_SIZE" -gt 0 ]; then
    touch "$FLAG"
  fi
  if [ "$CURRENT_SIZE" -gt "$LAST_SIZE" ]; then
    LAST_SIZE="$CURRENT_SIZE"
    WAITED=0
  else
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge "$WAIT" ]; then
      kill "$CURL_PID" 2>/dev/null
      wait "$CURL_PID" 2>/dev/null
      rm -f "$PIDFILE"
      cat "$OUTFILE" 2>/dev/null
      rm -f "$OUTFILE"
      exit 0
    fi
  fi
done

# Curl terminou normalmente
wait "$CURL_PID" 2>/dev/null
rm -f "$PIDFILE"
cat "$OUTFILE" 2>/dev/null
rm -f "$OUTFILE"
