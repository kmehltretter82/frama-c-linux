#!/bin/bash
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2023                                               #
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

# Example of installation of this pre-commit hook (client side):
# - (cd .git/hooks/ && ln -s ../../dev/git-hooks/pre-commit.sh pre-commit)
# Note: if you decide to copy the file, the `SCRIPT_DIR` variable must be
# fixed accordingly.

echo "Pre-commit Hook..."

STAGED=$(git diff --diff-filter ACMR --name-only --cached | sort)

if [ "$STAGED" = "" ];
then
  echo "Empty commit, nothing to do"
  exit 0
fi

SCRIPT_DIR=$(dirname -- "$( readlink -f -- "$0"; )")
"$SCRIPT_DIR/../check-files.sh" -c || exit 1
