#!/bin/sh
d="$1"
cd "$d" || exit 1
[ "$(ls fotos | wc -l | tr -d ' ')" = "4" ] || exit 1
[ -f indice.txt ] || exit 1
ls fotos | sed 's/\.[^.]*$//; s/ /_/g' | LC_ALL=C sort -f > /tmp/esperado_bench.txt
cmp -s /tmp/esperado_bench.txt indice.txt
