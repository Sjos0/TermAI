#!/bin/sh
d="$1"
cd "$d" || exit 1
[ -f ordem.txt ] || exit 1
sed -e '/^[[:space:]]*$/d' -e 's/[[:space:]]*$//' ordem.txt | sed -e '$a\' > /tmp/ordem_bench.txt
printf 'core\nlib-a\nlib-c\nlib-b\napp\n' > /tmp/ordem_esperada.txt
cmp -s /tmp/ordem_esperada.txt /tmp/ordem_bench.txt
