#!/bin/sh
d="$1"
cd "$d" || exit 1
[ "$(ls fotos | wc -l | tr -d ' ')" = "4" ] || exit 1
[ -f indice.txt ] || exit 1
ls fotos | sed 's/\.[^.]*$//; s/ /_/g' | LC_ALL=C sort -f > /tmp/esperado_bench.txt
# Normaliza a quebra de linha final: "um nome por linha" vale com ou sem \n no fim.
sed -e '$a\' indice.txt > /tmp/indice_bench.txt
cmp -s /tmp/esperado_bench.txt /tmp/indice_bench.txt
