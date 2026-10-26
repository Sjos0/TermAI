#!/bin/sh
d="$1"
cd "$d" || exit 1
[ -f relatorio.txt ] || exit 1
v=$(tr -s ' \r\n' ' ' < relatorio.txt | sed 's/^ *//; s/ *$//')
[ "$v" = "10.0.0.7 4" ]
