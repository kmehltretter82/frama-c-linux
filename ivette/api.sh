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

if [[ $# != 2 ]];
then
  cat <<EOF
usage: $0 [check|build] path
EOF
  exit 2
fi

case "$1" in
  "build") ;;
  "check") ;;
  *)
    echo "Bad first parameter: $1"
    echo "Exiting without doing anything.";
    exit 31
esac
action="$1"

if [[ ! -d $2 ]]; then
  echo "$2 directory doesn't exist"
fi
path=$2

build () {
  build_path=$1

  find $build_path/frama-c -path "*/api/*" -name "*.ts" -exec rm -f {} \;
	../bin/frama-c -server-tsc -server-tsc-out $build_path
	find $build_path/frama-c -path "*/api/*" -name "*.ts" \
		-exec headache \
			-h ../headers/open-source/CEA_LGPL \
			-c ../headers/headache_config.txt {} \;\
		-exec chmod a-w {} \;
}

tmp=
cleanup () {
  if [[ -n $tmp ]]; then
    rm -rf $tmp
  fi
}

check () {
  check_path=$1
  tmp="$(mktemp -d)"
  trap cleanup EXIT

  cp -r $check_path/frama-c $tmp/frama-c
  build $tmp
  diff -r $check_path/frama-c $tmp/frama-c
}

case "$action" in
  "build") build $path ;;
  "check") check $path ;;
esac
