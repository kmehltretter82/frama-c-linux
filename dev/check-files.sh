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

THIS_SCRIPT="$0"
LINT=check-lint
HDRCK=check-headers
DO_LINT="yes"
DO_HDRCK="yes"
REFERENCE=
MODE="all"

while [ "$1" != "" ]
do
    case "$1" in
        "-h"|"-help"|"--help")
            echo "${THIS_SCRIPT} [OPTIONS]"
            echo "OPTIONS"
            echo "  -h|-help|--help    print this message and exit"
            echo "  -f|--fix           fix files"
            echo "  -c|--commit        check modified files to be commited only"
            echo "  -p|--push          check modified files to be pushed only"
            echo "  --no-headers       do not check headers"
            echo "  --no-lint          do not check lint"
            exit 0
            ;;
        "-f"|"--fix")
            LINT=lint
            HDRCK=headers
            ;;
        "-p"|"--push")
            REFERENCE="origin/$(git rev-parse --abbrev-ref HEAD)"
            MODE="push"
            ;;
        "-c"|"--commit")
            MODE="commit"
            ;;
        "--no-headers")
            DO_HDRCK="no"
            ;;
        "--no-lint")
            DO_LINT="no"
            ;;
        *)
            echo "Unknown option '$1'"
            exit 2
            ;;
    esac
    shift
done

if [ "$MODE" = "all" ]; then
  if [ $DO_LINT = "yes" ] ; then
    make $LINT || exit 1
  fi
  if [ $DO_HDRCK = "yes" ] ; then
    make $HDRCK HDRCK_EXTRA="-quiet" || exit 1
  fi
else
  STAGED=$(git diff --diff-filter ACMR --name-only --cached $REFERENCE | sort)
  UNSTAGED=$(git diff --diff-filter DMR --name-only | sort)

  if [ "$STAGED" = "" ];
  then
    echo "No staged modification since last $MODE, nothing to do."
    exit 0
  fi

  if [ "$UNSTAGED" != "" ];
  then
    INTER=$(comm -12 <(ls $STAGED) <(ls $UNSTAGED))

    if [ "$INTER" != "" ];
    then
      echo "Cannot validate push."
      echo "The following staged files have been modified, renamed or deleted."
      for file in $INTER ; do
        echo "- $file"
      done
      exit 1
    fi
  fi

  STAGED=$(echo $STAGED | tr '\n' ' ')

  TMP=$(mktemp)

  cleanup () {
    rm "$TMP"
  }
  trap cleanup exit

  git check-attr -za $STAGED > "$TMP"
  if [ $DO_LINT = "yes" ] ; then
    make $LINT LINTCK_FILES_INPUT="$TMP" || exit 1
  fi
  git check-attr -z header_spec $STAGED > "$TMP"
  if [ $DO_HDRCK = "yes" ] ; then
    make $HDRCK HDRCK_FILES_INPUT="$TMP" HDRCK_EXTRA="-quiet" || exit 1
  fi
fi
