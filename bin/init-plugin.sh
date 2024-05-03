#! /usr/bin/env bash
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

if [[ $# != 1 && $# != 2 ]]; then
  echo "Usage: $0 <plugin-name> [<directory>]"
  exit 2
fi
if [[ $# == 1 ]]; then
  directory="."
else
  directory=$2
fi

if [[ ! -d $directory ]]; then
  echo "'$directory': not such file or directory"
  exit 17
fi

echo "Target directory is '$directory'"

dune_file=$directory/dune

if [[ -f $dune_file ]]; then
  echo "'$dune_file' file already exists."
  exit 17
fi

cat > $dune_file <<EOF
( library
  (name $1)
  (public_name frama-c-$1.core)
  (flags -open Frama_c_kernel :standard)
  (libraries frama-c.kernel)
)

(plugin (optional) (name $1) (libraries frama-c-$1.core) (site (frama-c plugins)))
EOF
