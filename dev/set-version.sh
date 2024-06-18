#! /bin/bash
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

NEXT=$1

if ! test -f VERSION; then
  echo "This script must be run from Frama-C root directory"
  exit 2
fi
if test -z "$NEXT"; then
  echo "Missing argument. Usage is:"
  echo "\$ ./dev/set-version.sh [<NN.M>|dev]"
  echo "See the Release Management Documentation for an example."
  exit 2
fi

# For macOS: use gsed if available, otherwise test if sed is BSD
if command -v gsed &>/dev/null; then
  SED=gsed
else
  if sed --version 2>/dev/null | grep -q GNU; then
    SED=sed
  else
    echo "GNU sed required"
    exit 1
  fi
fi

CURRENT=$(cat VERSION)
CURRENT_MAJOR=$(echo "$CURRENT" | $SED -e s/\\\([0-9]*\\\).[0-9]*.*/\\1/)
CURRENT_MINOR=$(echo "$CURRENT" | $SED -e s/[0-9]*.\\\([0-9]*\\\).*/\\1/)
CURRENT_CODENAME=$(grep "$CURRENT_MAJOR " ./doc/release/periodic-elements.txt | cut -d " " -f2)

if [[ $NEXT == "dev" ]]; then
  echo "Set VERSION to $CURRENT_MAJOR.$CURRENT_MINOR+dev"
  echo "Continue? [y/N] "
  read CHOICE
  case "${CHOICE}" in
  "Y" | "y") ;;
  *) exit 1 ;;
  esac

  echo "$CURRENT_MAJOR.$CURRENT_MINOR+dev" >VERSION
  $SED -i "s/^version: .*/version: \"$CURRENT_MAJOR.$CURRENT_MINOR+dev\"/g" opam
  $SED -i "s/^version: .*/version: \"$CURRENT_MAJOR.$CURRENT_MINOR+dev\"/g" tools/lint/frama-c-lint.opam
  $SED -i "s/^version: .*/version: \"$CURRENT_MAJOR.$CURRENT_MINOR+dev\"/g" tools/hdrck/frama-c-hdrck.opam
else
  NEXT_MAJOR=$(echo "$NEXT" | $SED -e s/\\\([0-9]*\\\).[0-9]*.*/\\1/)
  NEXT_MINOR=$(echo "$NEXT" | $SED -e s/[0-9]*.\\\([0-9]*\\\).*/\\1/)
  NEXT_CODENAME=$(grep "$NEXT_MAJOR " ./doc/release/periodic-elements.txt | cut -d " " -f2)

  echo "NEXT VERSION is:"
  echo "- MAJOR:    $NEXT_MAJOR"
  echo "- MINOR:    $NEXT_MINOR"
  echo "- CODENAME: $NEXT_CODENAME"

  echo ""
  echo "Continue? [y/N] "
  read CHOICE
  case "${CHOICE}" in
  "Y" | "y") ;;
  *) exit 1 ;;
  esac

  # Version

  echo "$NEXT" >VERSION
  echo "$NEXT_CODENAME" >VERSION_CODENAME

  # Opam files
  $SED -i "s/^version: .*/version: \"$NEXT\"/g" opam
  $SED -i "s/\(.*\)$CURRENT_MAJOR.$CURRENT_MINOR-$CURRENT_CODENAME\(.*\)/\1$NEXT_MAJOR.$NEXT_MINOR-$NEXT_CODENAME\2/g" opam

  $SED -i "s/^version: .*/version: \"$NEXT_MAJOR.$NEXT_MINOR\"/g" tools/lint/frama-c-lint.opam
  $SED -i "s/^version: .*/version: \"$NEXT_MAJOR.$NEXT_MINOR\"/g" tools/hdrck/frama-c-hdrck.opam

  # Changelogs

  FC_CL_MSG_FUTURE="Open Source Release <next-release>"
  FC_CL_MSG_NEXT="Open Source Release $NEXT_MAJOR.$NEXT_MINOR ($NEXT_CODENAME)"
  FC_CL_LIN="###############################################################################"

  $SED -i "s/\($FC_CL_MSG_FUTURE\)/\1\n$FC_CL_LIN\n\n$FC_CL_LIN\n$FC_CL_MSG_NEXT/g" Changelog

  EA_CL_MSG_FUTURE="Plugin E-ACSL <next-release>"
  EA_CL_MSG_NEXT="Plugin E-ACSL $NEXT_MAJOR.$NEXT_MINOR ($NEXT_CODENAME)"

  $SED -i "s/\($EA_CL_MSG_FUTURE\)/\1\n$FC_CL_LIN\n\n$FC_CL_LIN\n$EA_CL_MSG_NEXT/g" src/plugins/e-acsl/doc/Changelog

  WP_CL_MSG_FUTURE="Plugin WP <next-release>"
  WP_CL_MSG_NEXT="Plugin WP $NEXT_MAJOR.$NEXT_MINOR ($NEXT_CODENAME)"

  $SED -i "s/\($WP_CL_MSG_FUTURE\)/\1\n$FC_CL_LIN\n\n$FC_CL_LIN\n$WP_CL_MSG_NEXT/g" src/plugins/wp/Changelog

  # API doc
  find src -name '*.ml*' -exec $SED -i -e "s/Frama-C+dev/${NEXT_MAJOR}.${NEXT_MINOR}-${NEXT_CODENAME}/gI" '{}' ';'

  # Manuals changes
  $SED -i "s/\(^\\\\section\*{Frama-C+dev}\)/%\1\n\n\\\\section\*{$NEXT_MAJOR.$NEXT_MINOR ($NEXT_CODENAME)}/g" \
    doc/userman/user-changes.tex
  $SED -i "s/\(^\\\\section\*{Frama-C+dev}\)/%\1\n\n\\\\section\*{$NEXT_MAJOR.$NEXT_MINOR ($NEXT_CODENAME)}/g" \
    doc/developer/changes.tex
  $SED -i "s/\(^\\\\subsection{Frama-C+dev}\)/%\1\n\n\\\\subsection{Frama-C $NEXT_CODENAME}/g" \
    doc/aorai/main.tex
  $SED -i "s/\(^\\\\section\*{E-ACSL \\\\eacslpluginversion \\\\eacslplugincodename}\)/%\1\n\n\\\\section\*{E-ACSL $NEXT_MAJOR.$NEXT_MINOR $NEXT_CODENAME}/g" \
    src/plugins/e-acsl/doc/userman/changes.tex

  # Reference configuration
  $SED -i "s/Frama-C [1-9][0-9]\.[0-9]/Frama-C $NEXT_MAJOR.$NEXT_MINOR/gI" \
    reference-configuration.md

fi
