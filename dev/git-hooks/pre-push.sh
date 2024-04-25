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

ROOT=$(git rev-parse --show-toplevel)

echo "Pre-push Hook..."

empty=$(git hash-object --stdin </dev/null | tr '[0-9a-f]' '0')

remote=$1

while read local_ref local_oid remote_ref remote_oid
do
    if test "$local_oid" = "$empty"
    then
        # Handle delete
        :
    else
        if test "$remote_oid" = "$empty"
        then
            # New branch, examine commits starting
            # the forking point from master
            remote_oid=$(git merge-base $local_ref master);
        fi
        range="$remote_oid $local_oid";
        "$ROOT/dev/check-files.sh" -p "$range" || exit 1;
    fi;
done

exit 0
