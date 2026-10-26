#!/bin/sh
d="$1"
cd "$d" || exit 1
lua5.4 -e 'package.path="./?.lua;"..package.path; local c=require("calc"); assert(math.abs(c.media({3,5,10})-6)<1e-9); assert(math.abs(c.media({1,2})-1.5)<1e-9); assert(c.maximo({4,9,2})==9)' || exit 1
[ -f resultado.txt ] || exit 1
v=$(tr -d ' \r\n' < resultado.txt)
case "$v" in 6|6.0) exit 0;; *) exit 1;; esac
