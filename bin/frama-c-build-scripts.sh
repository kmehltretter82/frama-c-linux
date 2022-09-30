#!/bin/bash
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

PACKAGE="frama-c-scripts"


THIS_SCRIPT="$0"
Usage () {
    echo "Usage: $(basename ${THIS_SCRIPT}) <script-dir> [<modules>]"
    echo "  Build a script library to be used by Frama-C kernel"
    echo "Arguments"
    echo "  <script-dir>: directory that contents the script files:"
    echo "                - the basename of this directory fixes the name of the script library: ${PACKAGE}.<basename>"
    echo "                - a 'dune' file is created (if it does not exists before) into this directory"
    echo "                - a 'dune-project' file is created (if it does not exists before) into the parent directory"
    echo "                - note: the parent directory is './' when the script directory is also './'"
    echo "  <modules>: names of the OCaml modules that compose the script (default to all OCaml modules of the script directory)"
}

Error () {
    echo "Error: $@"
    Usage
    exit 1
}

[ "$1" != "" ] || Error "Missing argument: no script directory"
[ "$1" != "-h" ] || Usage
[ "$1" != "-help" ] || Usage
[ "$1" != "--help" ] || Usage

SCRIPT_DIR="$1"
shift
SCRIPT_FILES="$@"
SCRIPT_LIBS=""

[ -d "${SCRIPT_DIR}" ] || Error "Missing script directory: ${SCRIPT_DIR})"

###############

DuneProject () {
    echo "(lang dune 3.0)"
    echo "(package (name ${PACKAGE}))"
}

Dune () {
    echo "(rule"
    echo "  (alias ${PACKAGE})"
    echo "  (deps (universe))"
    echo "  (action (echo \"- Script ${SCRIPT_NAME}:\" %{lib-available:${PACKAGE}.${SCRIPT_NAME}} \"\\\\n\"))"
    echo ")"
    echo ""
    echo "(library"
    echo "  (name ${SCRIPT_NAME})"
    echo "  (optional)"
    echo "  (public_name ${PACKAGE}.${SCRIPT_NAME})"
    [ "${SCRIPT_FILES}" = "" ] || echo "  (modules ${SCRIPT_FILES})"
    echo "  (flags -open Frama_c_kernel :standard -w -9)"
    echo "  (libraries frama-c.kernel ${SCRIPT_LIBS})"
    echo ")"
}

###############

GenerateFile () {
    if [ -e "$2" ]; then
        echo "$1 file exists already: $2"
    else
        echo "- Generate $1 file: $2"
        $1 | while read p; do
            echo "$p" >> "$2"
        done
    fi
}

###############

SCRIPT_NAME="$(basename "${SCRIPT_DIR}")"
DUNE_PROJECT_DIR="$(dirname "${SCRIPT_DIR}")"
DUNE_PROJECT="${DUNE_PROJECT_DIR}/dune-project"
case "${SCRIPT_DIR}" in
    */) DUNE_FILE="${SCRIPT_DIR}dune" ;;
    *) DUNE_FILE="${SCRIPT_DIR}/dune" ;;
esac

###############

[ "$(basename "${DUNE_FILE}")" = "dune" ] || Error "Wrong basename for a dune file: ${DUNE_FILE}"
[ "$(basename "${DUNE_PROJECT}")" = "dune-project" ] || Error "Wrong basename for a dune-project file: ${DUNE_PROJECT}"

GenerateFile Dune "${DUNE_FILE}"
GenerateFile DuneProject "${DUNE_PROJECT}"

echo "To compile the scripts, runs the following command:"
if [ "${DUNE_PROJECT_DIR}" = "." ]; then
    echo "  dune build @install"
else
    echo "  (cd ${DUNE_PROJECT_DIR} && dune build)"
fi
echo "So, the script, is installed into the local '_build' directory."
echo "To load the script from Frama-C, runs the following command:"
echo "  frama-c -load-module $(realpath ${DUNE_PROJECT_DIR}/_build/install/default/lib/${PACKAGE}/${SCRIPT_NAME})/${SCRIPT_NAME} ..."
