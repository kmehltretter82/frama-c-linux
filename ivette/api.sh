#! /usr/bin/env bash
##########################################################################
#                                                                        #
#  SPDX-License-Identifier LGPL-2.1                                      #
#  Copyright (C)                                                         #
#  CEA (Commissariat à l'énergie atomique et aux énergies alternatives)  #
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
		-h ../headers/CEA_LGPL \
		-c ../headers/headache_config.txt {} \;\
	-exec chmod a-w {} \;
