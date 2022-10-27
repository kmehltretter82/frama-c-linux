#!/bin/bash
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2022                                               #
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

# Examples of installation of this pre-commit hook (client side):
# - cp ./dev/git-hooks/pre-commit.sh .git/hooks/pre-commit
# - (cd .git/hooks/ && ln -s ../../dev/git-hooks/pre-commit.sh pre-commit)

echo "Pre-commit Hook..."

STAGED=$(git diff --diff-filter ACMR --name-only --cached | sort)
UNSTAGED=$(git diff --diff-filter DMR --name-only | sort)

INTER=$(comm -12 <(ls $STAGED) <(ls $UNSTAGED))

if [ "$INTER" != "" ];
then
    echo "Cannot validate commit."
    echo "The following staged files have been modified, renamed or deleted."
    for file in $INTER ; do
        echo "- $file"
    done
    exit 1
fi

STAGED=$(echo $STAGED | tr '\n' ' ')

TMP=$(mktemp)

cleanup () {
  rm "$TMP"
}
trap cleanup exit

git check-attr -za $STAGED > "$TMP"
make lint LINTCK_FILES_INPUT="$TMP" || exit 1
git check-attr -z header_spec $STAGED > "$TMP"
make check-headers HDRCK_FILES_INPUT="$TMP" HDRCK_EXTRA="-quiet" || exit 1
