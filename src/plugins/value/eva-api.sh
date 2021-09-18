#!/bin/bash -eu

header=$1
shift

IFS='' # for read to keep spaces

printf '('
printf '%0.1s' '*'{1..74}
printf ')\n'
while read -r line
do
    printf '(*  %-68s  *)\n' $line
done < $header
printf '('
printf '%0.1s' '*'{1..74}
printf ')\n\n'
printf '(* This file is generated. Do not edit. *)\n\n'

for i in "$@"
do
    file=$(basename $i)
    module=${file%.*}
    printf 'module %s: sig\n' ${module^}
    awk '/\[@@@ api_start\]/{flag=1;next} /\[@@@ api_end\]/{flag=0} flag{ print  " ", $0 }' $i
    printf 'end\n\n'
done
