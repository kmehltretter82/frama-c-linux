#!/bin/bash
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

if [ $# -lt 1 ]
then
  (
    echo "usage: $0 FILE STRING"
    echo "Test whether the contents of FILE are different from STRING." \
         "If it does, FILE is updated to match STRING. The file" \
         "name is always printed."
  ) >&2
  exit 1
fi

FILE=$1
shift
STRING=$*

if
  [ ! -e "$FILE" ] ||
  ! (diff --brief --ignore-space-change "$FILE" - >/dev/null <<< "$STRING")
then
  mkdir -p "$(dirname "$FILE")"
  echo "$STRING" > "$FILE"
fi

echo "$FILE"
