#!/usr/bin/env bash
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

set -euxo pipefail

if [ ! -f configure ] ; then
  echo "No 'configure' file, you should first run 'autoconf'"
  exit 2
fi

EXTERNAL_PLUGINS=$(find src/plugins -type d -name ".git" | sed "s/.git//")

FRAMAC="frama-c.tar"
git archive HEAD -o $FRAMAC --prefix "frama-c/"

ACC=$FRAMAC

for plugin in $EXTERNAL_PLUGINS ; do
   TAR="$(basename $plugin).tar"
   git -C $plugin archive HEAD -o $TAR --prefix "frama-c/$plugin/"
   ACC="$ACC $plugin$TAR"
done

tar --concatenate --file=$ACC
tar rf $FRAMAC configure --transform 's,^,frama-c/,'
gzip -9 < $FRAMAC > $FRAMAC.gz

rm -f $ACC
