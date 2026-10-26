#!/bin/sh
d="$1"
cd "$d" || exit 1
[ -f total.txt ] || exit 1
v=$(tr -d ' \r\n' < total.txt)
[ "$v" = "125" ]
