#!/bin/bash
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

PACKAGE="frama-c-scripts"

CMD="init"

THIS_SCRIPT="$0"
Usage () {
    echo "Usage: $(basename ${THIS_SCRIPT}) [<command>] [options] <script-dir> [<modules>]"
    echo "  Builds a script library to be used by the Frama-C kernel."
    echo ""
    echo "Commands:"
    echo "- init: generates dune files (default command)"
    echo "- build: performs the compilation of the script libraries via \"dune build @install\""
    echo "- install: performs the installation of the script libraries via \"dune install\""
    echo ""
    echo "Options:"
    echo "  -help: prints usage information"
    echo "  -package-name <name>: sets the <name> of the package of the libraries (defaults to \"${PACKAGE}\")."
    echo "                        note: once the dune-project file has been created, don't set another name."
    echo ""
    echo "Arguments:"
    echo "  <script-dir>: directory that contains the script files:"
    echo "                - the basename of this directory fixes the name of the script library: ${PACKAGE}.<basename>"
    echo "                - a 'dune' file is created (if it does not exist) in this directory"
    echo "                - a 'dune-project' file is created (if it does not exist) in the parent directory"
    echo "                - note: the parent directory is './' when the script directory is also './'"
    echo "  <modules>: names of the OCaml modules that compose the script (defaults to all OCaml modules of the script directory)"
}

Error () {
    echo "Error: $@"
    Usage
    exit 1
}

###############
# Command line processing

case "$1" in
    "init"|"build"|"install") CMD="$1"; shift;;
    *) ;;
esac

while [ "$1" != "" ]; do
    case "$1" in
        "-package-name") shift ; PACKAGE="$1";;
        "-h"|"-help"|"--help") Usage; exit 0;;
        *) break ;;
    esac
    shift
done

[ "$PACKAGE" != "" ] || Error "missing option value: package name"
[ "$1" != "" ] || Error "missing argument: script directory"

SCRIPT_DIR="$1"
shift
SCRIPT_FILES="$@"
SCRIPT_LIBS=""

[ -d "${SCRIPT_DIR}" ] || Error "Script directory does not exist: ${SCRIPT_DIR})"

###############

DuneProject () {
    echo "(lang dune 3.7)"
    echo "(generate_opam_files true)"
    echo "(name ${PACKAGE})"
    echo "(maintainers \"anonymous\")"
    echo "(package (name ${PACKAGE})"
    echo "  (depends"
    echo "    (\"frama-c\" (>= 28.1))"
    echo "  )"
    echo " (tags (\"Frama-C scripts\"))"
    echo ")"
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
        echo "$1 file already exists: $2"
    else
        echo "- Creating $1 file: $2"
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

EchoDuneCmd() {
    if [ "${DUNE_PROJECT_DIR}" = "." ]; then
        echo "  > $@"
    else
        echo "  > (cd ${DUNE_PROJECT_DIR} && $@)"
    fi
}

DuneBuild() {
    echo ""
    echo "- Compiling the script library \"${PACKAGE}.${SCRIPT_NAME}\" via \"dune build @install\" command..."
    dune build @install
    [ "$?" = "0" ] || Error "compilation failure"
}

DuneInstall() {
    echo ""
    echo "- Install the script library \"${PACKAGE}.${SCRIPT_NAME}\" via \"dune install\" command..."
    dune install
}

###############

[ "$(basename "${DUNE_FILE}")" = "dune" ] || Error "Wrong basename for a dune file: ${DUNE_FILE}"
[ "$(basename "${DUNE_PROJECT}")" = "dune-project" ] || Error "Wrong basename for a dune-project file: ${DUNE_PROJECT}"

GenerateFile DuneProject "${DUNE_PROJECT}"
GenerateFile Dune "${DUNE_FILE}"

if [ "$CMD" = "init" ]; then
    echo ""
    echo "To compile all scripts defined inside this 'dune project' \"${PACKAGE}\", run:"
    EchoDuneCmd "dune build @install"
else
    DuneBuild
fi
echo ""
echo "Script libraries have been compiled and installed into the local '_build' directory."
echo "An 'opam' file \"${PACKAGE}.opam\" has been created/updated, allowing a global installation of all script libraries."
echo ""
echo "To load this script library from Frama-C, run the following command:"
EchoDuneCmd "dune exec -- frama-c -load-library ${PACKAGE}.${SCRIPT_NAME} ..."

if [ "$CMD" = "install" ]; then
    DuneInstall
else
    echo ""
    echo "All libraries of this 'dune project' \"${PACKAGE}\" can also be installed via 'dune' using from the generated 'opam' file: \"${PACKAGE}.opam\""
    EchoDuneCmd "dune install"
fi
echo ""
echo "After installation, this script library can be directly loaded by Frama-C with:"
echo "  > frama-c -load-library ${PACKAGE}.${SCRIPT_NAME} ..."
