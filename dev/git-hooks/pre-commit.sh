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

# Note:
# - that checks the unstaged version of the files and these files are
#   only commited with a `git commit -a` command.
# - so, a `git commit` command may  checks the wrong version of a file.

echo "Pre-commit Hook..."

# Extract the files that have both an unstaged version and a staged one.
UNSTAGED="git diff --name-status"
STAGED="git diff --name-status --cached"
(($UNSTAGED ; $STAGED) | sed "s:^.::" | sort -u) | diff - <(($UNSTAGED ; $STAGED) | sed "s:^.::" | sort)
if [ "$?" != "0" ]; then
    echo "WARNING: These previous files are both unstaged and in the index."
    echo "         They will be verified only for a 'git commit -a' command."
fi

# Verifies the current version of files
make lint.before-commit-a
make check-headers.before-commit-a
