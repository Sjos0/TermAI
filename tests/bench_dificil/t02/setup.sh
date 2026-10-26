#!/bin/sh
d="$1"
printf 'nome,cidade\n"Silva, Ana",Recife\n"Souza, Bia",Natal\n"Lima, Caio",Belém\n' > "$d/dados.csv"
