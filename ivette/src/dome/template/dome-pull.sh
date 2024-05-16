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

# --------------------------------------------------------------------------
# ---  Pulling Dome Updates
# --------------------------------------------------------------------------

if [ ! -z "$(git status --porcelain)" ]
then
    echo "Local non-commited modifications, aborted."
    exit 1
fi

if [ ! -d .gitdome ]
then
    git clone git@git.frama-c.com:dome/electron.git .gitdome
fi

head=$(git rev-parse --abbrev-ref HEAD)
commit=$(git -C .gitdome rev-parse HEAD)
remote=$(git -C .gitdome rev-parse --abbrev-ref HEAD)

git checkout stable/dome

if [ "$?" != "0" ]
then
    echo "Missing local branch stable/dome, aborted."
    exit 1
fi

echo "Pulling Dome updates from $remote to stable/dome..."
git -C .gitdome pull --prune

for f in $(git -C .gitdome ls-files)
do
    mkdir -p $(dirname $f)
    cp -f .gitdome/$f $f
    git add $f
done

if [ ! -z "$(git status --porcelain)" ]
then
    git commit -m "[Dome] $commit"
    echo "Dome repository updated."
    git checkout $head
    echo "Merging Dome updates..."
    git merge stable/dome
else
    echo "Dome is already up-to-date."
    git checkout $head
fi

# --------------------------------------------------------------------------
