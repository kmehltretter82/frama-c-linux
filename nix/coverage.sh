#!/usr/bin/env sh
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

if [ -z ${BISECT_DIR+x} ]; then
  echo "BISECT_DIR variable must indicate the reports directory"
  exit 2
fi

for i in _bisect/*.tar.xz ; do
  tar xfJ "$i" ;
done

combinetura ./*.xml -o report.xml

LINE=$(sed -n '2p' report.xml)
RATE=$(echo "$LINE" | sed -e 's/.*line-rate=\"\(.*\)\".*/\1/')

PERCENT="0.0"
if [ "$RATE" != "-nan" ]; then
  # Keep the "/1", bc DOES NOT use scale for anything else than division ...
  PERCENT=$(echo "scale=2; (100 * $RATE)/1" | bc -l)
fi

echo "Coverage: $PERCENT%"
