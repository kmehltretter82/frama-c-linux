#!/usr/bin/env bash
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2024                                               #
#    CEA (Commissariat à l'énergie atomique et aux énergies              #
#         alternatives)                                                  #
#                                                                        #
#  you can redistribute it and/or modify it under the terms of the GNU   #
#  Lesser General Public License as published by the Free Software       #
#  Foundation, version 2.1.                                              #
#                                                                        #
#  It is distributed in the hope that it will be useful,                 #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of        #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         #
#  GNU Lesser General Public License for more details.                   #
#                                                                        #
#  See the GNU Lesser General Public License version 2.1                 #
#  for more details (enclosed in the file licenses/LGPLv2.1).            #
#                                                                        #
##########################################################################

set -eu

dir=$(dirname $0)

# Generate MLI

cat $dir/Eva.header >> Eva.mli

for i in "$@"
do
    if [[ ! "$i" =~ [.]header$ ]]; then
        file=$(basename $i)
        module=${file%.*}
        Module="$(echo "${module:0:1}" | tr '[:lower:]' '[:upper:]')${module:1}"
        printf '\nmodule %s: sig\n' $Module >> Eva.mli
        awk '/\[@@@ api_start\]/{flag=1;next} /\[@@@ api_end\]/{flag=0} flag{ print (NF ? "  ":"") $0 }' $i  >> Eva.mli
        printf 'end\n' >> Eva.mli
    fi
done

# Generate ML

cat $dir/Eva.header >> Eva.ml

for i in "$@"
do
    if [[ ! "$i" =~ [.]header$ ]]; then
        file=$(basename $i)
        module=${file%.*}
        Module="$(echo "${module:0:1}" | tr '[:lower:]' '[:upper:]')${module:1}"
        printf '\nmodule %s = %s\n' $Module $Module >> Eva.ml
    fi
done
