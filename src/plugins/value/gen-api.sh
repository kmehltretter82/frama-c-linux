#!/usr/bin/env bash
set -eu

dir=$(dirname $0)

# Generate MLI

cat $dir/Eva.mli.in >> Eva.mli

printf '\n(** Eva public API.

   The main modules are:
   - Analysis: run the analysis.
   - Results: access analysis results, especially the values of expressions
      and memory locations of lvalues at each program point.

   The following modules allow configuring the Eva analysis:
   - Parameters: change the configuration of the analysis.
   - Eva_annotations: add local annotations to guide the analysis.
   - Builtins: register ocaml builtins to be used by the cvalue domain
       instead of analysing the body of some C functions.

   Other modules are for internal use only. *)\n' >> Eva.mli

printf '\n(* This file is generated. Do not edit. *)\n' >> Eva.mli

for i in "$@"
do
    if [[ ! "$i" =~ [.]in$ ]]; then
        file=$(basename $i)
        module=${file%.*}
        printf '\nmodule %s: sig\n' ${module^}  >> Eva.mli
        awk '/\[@@@ api_start\]/{flag=1;next} /\[@@@ api_end\]/{flag=0} flag{ print (NF ? "  ":"") $0 }' $i  >> Eva.mli
        printf 'end\n' >> Eva.mli
    fi
done

# Generate ML

cat $dir/Eva.ml.in >> Eva.ml

for i in "$@"
do
    if [[ ! "$i" =~ [.]in$ ]]; then
        file=$(basename $i)
        module=${file%.*}
        printf '\nmodule %s = %s\n' ${module^} ${module^} >> Eva.ml
    fi
done
