#!/bin/sh
# Tarefas difíceis sem Docker, com o modelo Kilo gratuito. Pensado para o GitHub Actions.
# Uso: sh tests/bench_dificil/run.sh [repeticoes]
set -u
REPS=${1:-3}
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
WS="$HOME/.TermAI/workspace/bench"
OUT=${E2E_OUT:-/tmp/termai-bench-out}
MODEL=${BENCH_MODEL:-kilo/kilo-auto/free}
mkdir -p "$OUT"
(cd "$ROOT" && lua5.4 tests/bench_dificil/preparar.lua) || exit 1
echo "tarefa,rep,resultado,segundos" > "$OUT/resultados.csv"
for t in ${TAREFAS:-t01 t02 t03 t04 t05 t06 t07 t08}; do
  r=1
  while [ "$r" -le "$REPS" ]; do
    dir="$WS/$t-$r"
    rm -rf "$dir"; mkdir -p "$dir"
    sh "$ROOT/tests/bench_dificil/$t/setup.sh" "$dir"
    sed "s#DIR#$dir#g" "$ROOT/tests/bench_dificil/$t/prompt.md" > "$OUT/$t-$r.prompt.md"
    ini=$(date +%s)
    (cd "$ROOT" && timeout 600 lua5.4 main.lua run --permitir-sempre --model "$MODEL" --prompt-file "$OUT/$t-$r.prompt.md" > "$OUT/$t-$r.log" 2>&1 < /dev/null)
    fim=$(date +%s)
    if sh "$ROOT/tests/bench_dificil/$t/check.sh" "$dir" > "$OUT/$t-$r.check.txt" 2>&1; then res=ok; else res=falhou; fi
    echo "$t,$r,$res,$((fim-ini))" >> "$OUT/resultados.csv"
    r=$((r+1))
  done
done
cat "$OUT/resultados.csv"
