#! /usr/bin/bash
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

if   [[ $# > 1 ]] ; then
  echo "usage: $0 [ configuration_file ]"
  exit 1
elif [[ $# = 1 ]] ; then
  source $1
fi

VERSION=${VERSION:-$(cat VERSION)}
CODENAME=${CODENAME:-$(cat VERSION_CODENAME)}

FRAMAC=frama-c-$VERSION-$CODENAME

FPATH=$FRAMAC/

git archive --format=tar --prefix $FPATH HEAD > $FRAMAC.tar

TRANSFO="s,^,$FPATH,"
tar rf $FRAMAC.tar configure --transform $TRANSFO
