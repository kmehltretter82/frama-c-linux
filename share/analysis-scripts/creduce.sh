#!/bin/bash -e
##########################################################################
#                                                                        #
#  This file is part of Frama-C.                                         #
#                                                                        #
#  Copyright (C) 2007-2020                                               #
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

# Script to run C-Reduce (https://embed.cs.utah.edu/creduce) when debugging
# Frama-C crashes with a 'fatal' error, which produces a stack trace and
# a message "Please report".

### Requirements
#
# - C-Reduce installed in the PATH, or its path given in the
#   environment variable CREDUCE;
#
# - GCC, or the path to a compiler with compatible options given in the
#   environment variable CC;
#
# - Frama-C installed in the PATH, or its path given in the environment
#   variable FRAMAC;
#
# - a source file + a command line which causes Frama-C to crash with
#   a 'fatal' error (producing a stack trace).

### How it works
#
#   creduce.sh <file.c> <command line options>
#
# This script creates a temporary directory named 'creducing'.
# It copies <file.c> inside it, then runs creduce.
# creduce runs "frama-c <command line options>" on the copied file,
# modifying it to make it smaller while still crashing.
#
# When done, copy the reduced file and erase directoy 'creducing'.

if [ $# -lt 1 ]; then
    echo "usage: $0 file.c [Frama-C options that cause a crash]"
    exit 1
fi

file="$1"
base=$(basename "$file")
shift
options="$@"
dir_for_reduction="creducing"

if [ -z "$CREDUCE" ]; then
    CREDUCE="creduce"
fi

if ! command -v "$CREDUCE" 2>&1 >/dev/null; then
    echo "creduce not found, put it in PATH or in environment variable CREDUCE."
    exit 1
fi

if [[ ! -f "$file" ]]; then
    echo "Source file not found (must be first argument): $file"
    exit 1
fi

if [[ $(dirname "$file") -eq "$dir_for_reduction" ]]; then
    echo "error: cannot reduce a file inside the directory used for reduction,"
    echo "       $dir_for_reduction"
    exit 1
fi

if [[ ! "$options" =~ no-autoload-plugins ]]; then
    echo "********************************************************************"
    echo "Hint: consider using -no-autoload-plugins -load-module [modules]"
    echo "      for faster reduction"
    echo "********************************************************************"
fi

if [[ "$base" =~ \.c$ ]]; then
    echo "********************************************************************"
    echo "Hint: consider passing a preprocessed (.i) file if possible,"
    echo "      otherwise #includes may prevent further reduction"
    echo "********************************************************************"
fi

mkdir -p "$dir_for_reduction"

if [ -z "$FRAMAC" ]; then
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    FRAMAC=$(realpath "$SCRIPT_DIR/../../bin/frama-c")
    echo "[info] FRAMAC not set, using binary at: $FRAMAC"
else
    echo "[info] using FRAMAC: $FRAMAC"
fi

if [ -z "$FRAMAC_SHARE" ]; then
    FRAMAC_SHARE="$("$FRAMAC" -print-share-path)"
fi

if [ -z "$CC" ]; then
    CC=gcc
    CFLAGS+="-fsyntax-only -I\"$FRAMAC_SHARE\"/libc -D__FC_MACHDEP_X86_32 -m32"
fi

echo "[info] checking syntactic validity with: $CC $CFLAGS"

cp "$file" "$dir_for_reduction"
cd "$dir_for_reduction"

cat <<EOF > script_for_creduce.sh
#!/bin/bash -e

# This script is given to creduce to reduce a Frama-C crashing test case
# (where "crashing" means a 'fatal' exception, with stack trace).

set +e
$CC $CFLAGS "$base"
if [ \$? -ne 0 ]; then
   exit 1
fi
"$FRAMAC" "$base" $options
retcode=\$?
# see cmdline.ml for the different exit codes returned by Frama-C
if [ \$retcode -eq 125 -o \$retcode -eq 4 ]; then
    exit 0
else
    exit 1
fi
set -e

EOF

chmod u+x script_for_creduce.sh

trap "{ echo \"Creduce interrupted!\"; echo \"\"; echo \"(partially) reduced file: $dir_for_reduction/$base\"; exit 0; }" SIGINT

echo "File being reduced: $dir_for_reduction/$base (press Ctrl+C to stop at any time)"

set +e
./script_for_creduce.sh 2>&1 >/tmp/script_for_creduce.out
if [ $? -ne 0 ]; then
    echo "error: script did not produce a Frama-C 'fatal' crash."
    echo "       check the options given to Frama-C to ensure they make Frama-C crash."
    echo ""
    echo "Script output:"
    cat /tmp/script_for_creduce.out
    exit 1
fi
set -e

"$CREDUCE" script_for_creduce.sh "$base"

echo "Finished reducing file: $dir_for_reduction/$base"
