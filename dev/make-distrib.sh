#!/usr/bin/env bash
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

set -euxo pipefail

if [ ! -f configure ] ; then
  echo "No 'configure' file, you should first run 'autoconf'"
  exit 2
fi

################################################################################
# Configuration

if [ -z ${OPEN_SOURCE+x} ]; then
  echo "OPEN_SOURCE variable not set, defaults to 'no'"
  OPEN_SOURCE="no"
fi

if [ -z ${HDRCK+x} ]; then
  HDRCK="dune exec -- frama-c-hdrck"
fi

if [ -z ${VERSION+x} ]; then
  VERSION=$(cat VERSION | sed "s,~,-,")
fi

if [ -z ${VERSION_CODENAME+x} ]; then
  VERSION_CODENAME=$(cat VERSION_CODENAME)
fi

if [ -z ${CI_LINK+x} ]; then
  CI_LINK="no"
fi

FRAMAC="frama-c-$VERSION-$VERSION_CODENAME"
FRAMAC_TAR="$FRAMAC.tar"

################################################################################
# Prepare archive


git archive HEAD -o $FRAMAC_TAR --prefix "$FRAMAC/"

TAR_ACC=$FRAMAC_TAR

EXTERNAL_PLUGINS=$(find src/plugins -type d -name ".git" | sed "s/\/.git//")

for plugin in $EXTERNAL_PLUGINS ; do
   TAR="$(basename $plugin).tar"
   git -C $plugin archive HEAD -o $TAR --prefix "$FRAMAC/$plugin/"
   TAR_ACC="$TAR_ACC $plugin/$TAR"
done

tar --concatenate --file=$TAR_ACC
tar rf $FRAMAC_TAR configure --transform "s,^,$FRAMAC/,"

################################################################################
# Prepare header options

if [[ "$OPEN_SOURCE" == "yes" ]]; then
  HEADER_KIND="open-source"
  HEADER_OPT=
else
  HEADER_KIND="close-source"
  HEADER_OPT="-update"
fi

################################################################################
# Prepare header spec

HEADER_SPEC="header-spec.txt"
git ls-files -z | git check-attr --stdin -z header_spec > $HEADER_SPEC

HEADER_DIRS="-header-dirs headers/$HEADER_KIND"

for plugin in $EXTERNAL_PLUGINS ; do
  git -C $plugin ls-files -z |\
  git -C $plugin check-attr --stdin -z header_spec |\
  xargs --null -n3 printf "$plugin/%s\n%s\n%s\n" |\
  tr '\n' '\0' >> $HEADER_SPEC
done

PLUGINS=$(find src/plugins -type d -mindepth 1 -maxdepth 1)

for plugin in $PLUGINS ; do
  HEADER_DIRS="$HEADER_DIRS -header-dirs $plugin/headers/$HEADER_KIND"
done

################################################################################
# Headers

TMP_DIR=$(mktemp -d)
echo $TMP_DIR
tar xf $FRAMAC_TAR -C $TMP_DIR

$HDRCK $HEADER_OPT $HEADER_DIRS -spec-format="3-zeros" -C "$TMP_DIR/$FRAMAC" $HEADER_SPEC
echo $VERSION > $TMP_DIR/$FRAMAC/VERSION
echo $VERSION_CODENAME > $TMP_DIR/$FRAMAC/VERSION_CODENAME

################################################################################
# Finalize archive

tar czf $FRAMAC_TAR.gz -C $TMP_DIR $FRAMAC

if [[ "$CI_LINK" == "yes" ]]; then
  ln $FRAMAC_TAR.gz "frama-c.tar.gz"
fi

################################################################################
# Cleaning

rm -rf $HEADER_SPEC
rm -rf $TAR_ACC
rm -rf $TMP_DIR
