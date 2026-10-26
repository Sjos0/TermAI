#!/bin/sh
d="$1"
cd "$d" || exit 1
[ -f limpo.txt ] || exit 1
printf '3;Bruno\n5;Carla\n7;Ana Paula\n' > /tmp/limpo_esperado.txt
sed -e '$a\' limpo.txt > /tmp/limpo_bench.txt
cmp -s /tmp/limpo_esperado.txt /tmp/limpo_bench.txt
