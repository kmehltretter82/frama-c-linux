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
# - cp ./tools/git-hooks/pre-commit.sh .git/hooks/pre-commit
# - (cd .git/hooks/ && ln -s ../../tools/git-hooks/pre-commit.sh pre-commit)

# Note:
# - that checks the unstaged version of the files and these files are
#   only commited with a `git commit -a` command.
# - so, a `git commit` command may checks the wrong version of a file.

echo "Pre-commit Hook looking at staged and unstaged file version..."
## looks at unstaged and staged files
make lint.before-commit-a
