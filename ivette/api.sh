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

if [ -z ${DUNE_WS+x} ]; then
  WORKSPACE_OPT=
else
  WORKSPACE_OPT="--workspace ../dev/dune-workspace.${DUNE_WS} --context ${DUNE_WS}"
fi

find $path/frama-c -path "*/api/*" -name "*.ts" -exec rm -f {} \;
dune exec ${WORKSPACE_OPT} -- frama-c -server-tsc $path
find $path/frama-c -path "*/api/*" -name "*.ts" -exec chmod a-w {} \;
