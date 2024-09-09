#! /usr/bin/env bash
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

if [[ $# != 1 ]];
then
  cat <<EOF
usage: $0 path
EOF
  exit 2
fi

if [[ ! -d $1 ]]; then
  echo "$1 directory doesn't exist"
fi
path=$1

find $path/frama-c -path "*/api/*" -name "*.ts" -exec rm -f {} \;
	../bin/frama-c -server-tsc -server-tsc-out $path
find $path/frama-c -path "*/api/*" -name "*.ts" \
	-exec headache \
		-h ../headers/open-source/CEA_LGPL \
		-c ../headers/headache_config.txt {} \;\
	-exec chmod a-w {} \;
