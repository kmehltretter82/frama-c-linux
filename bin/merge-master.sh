#!/bin/sh
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

if test -z "$1"; then
    echo "Syntax: $0 <release name>";
    exit 1
fi

# Name of the release branch to merge in master
BRANCH="stable/$1"

# Last merge commit between master and the release
ANCESTOR=$(git merge-base $BRANCH master)

# Find Gitlab text ('See merge request') and extract merge numbers
MR=$(git log --format='%b' --merges $ANCESTOR..$BRANCH \
            | sed -n 's/See merge request \(![0-9]*\)/\1/p' \
            | tr '\n' ' ' )

git merge $BRANCH -m "Merging $BRANCH into master ($MR)"
