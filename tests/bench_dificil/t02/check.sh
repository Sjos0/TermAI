#!/bin/sh
d="$1"
cd "$d" || exit 1
[ -f contagem.txt ] || exit 1
l1=$(sed -n 1p contagem.txt | tr -d ' \r')
l2=$(sed -n 2p contagem.txt | sed 's/\r$//; s/^ *//; s/ *$//')
[ "$l1" = "3" ] && [ "$l2" = "Souza, Bia" ]
