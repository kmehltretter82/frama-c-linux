#!/bin/bash -eu

printf '(* This file is generated. Do not edit. *)\n'

for i in "$@"
do
    file=$(basename $i)
    module=${file%.*}
    printf '\nmodule %s: sig\n' ${module^}
    awk '/\[@@@ api_start\]/{flag=1;next} /\[@@@ api_end\]/{flag=0} flag{ print (NF ? "  ":"") $0 }' $i
    printf 'end\n'
done
