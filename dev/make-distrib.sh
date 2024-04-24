#!/usr/bin/env bash
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

################################################################################
# Configuration

if [ -z ${OPEN_SOURCE+x} ]; then
  echo "OPEN_SOURCE variable not set, defaults to 'no'"
  OPEN_SOURCE="no"
fi

if [ -z ${HDRCK+x} ]; then
  HDRCK="dune exec -- frama-c-hdrck"
fi

if [ -z ${VERSION_CODENAME+x} ]; then
  VERSION_CODENAME=$(cat VERSION_CODENAME)
fi

if [ -z ${CI_LINK+x} ]; then
  CI_LINK="no"
fi

# For macOS: use gtar if available, otherwise test if tar is BSD
if command -v gtar &> /dev/null; then
  TAR=gtar
else
  if tar --version | grep -q bsdtar; then
    echo "GNU tar required"
    exit 1
  fi
  TAR=tar
fi


################################################################################
# Command Line

while [ "$1" != "" ]
do
    case "$1" in
        "-h"|"-help"|"--help")
            echo "Make Frama-C Source Distribution"
            echo ""
            echo "USAGE"
            echo ""
            echo "  ./dev/make-distrib.sh [OPTIONS]"
            echo ""
            echo "OPTIONS"
            echo ""
            echo "  --help            Print this help message"
            echo "  --closed-source   Set closed source header mode (default)"
            echo "  --open-source     Set open source header mode"
            echo "  --ci-link         Symlink to frama-c.tar.gz"
            echo "  --hdrck <cmd>     Check headers command"
            echo "  --codename <name> Set local VERSION_CODENAME"
            echo ""
            echo "ENVIRONMENT VARIABLES"
            echo ""
            echo ""
            echo "  HDRCK=<cmd> (overriden set by --hdrck)"
            echo "  VERSION_CODENAME=<name> (overriden by --codename)"
            echo "  OPEN_SOURCE=yes|no (overriden by --open-source and --closed-source)"
            echo "  CI_LINK=yes|no (also set by --ci-link)"
            echo ""
            exit 0
            ;;
        "--hdrck")
            shift
            HDRCK="$1"
            ;;
        "--codename")
            shift
            VERSION_CODENAME=$1
            ;;
        "--open-source")
            OPEN_SOURCE=yes
            ;;
        "--closed-source")
            OPEN_SOURCE=no
            ;;
        "--ci-link")
            CI_LINK=yes
            ;;
        *)
            echo "Don't know what to do with option '$1'"
            exit 1
            ;;
    esac
    shift
done

################################################################################
# Target Names

VERSION=$(cat VERSION)
VERSION_SAFE=${VERSION/~/-}

FRAMAC="frama-c-$VERSION_SAFE-$VERSION_CODENAME"
FRAMAC_TAR="$FRAMAC.tar"

################################################################################
# Check Opam file

OPAM_VERSION=$(cat opam | grep "^version" | sed 's/version: \"\(.*\)\"/\1/')

if [ "$VERSION" != "$OPAM_VERSION" ]; then
  echo "VERSION ($VERSION) and OPAM_VERSION ($OPAM_VERSION) differ"
  exit 2
fi

################################################################################
# Check that no versioned file is ignored

IGNORED_FILES="$(git ls-files --ignored --exclude-standard -c)"
if [ "" != "$IGNORED_FILES" ]; then
  echo "Some versioned files are ignored by .gitignore:"
  echo $IGNORED_FILES
  exit 2
fi

################################################################################
# External Plugins

PLUGINS=$(find src/plugins -mindepth 1 -maxdepth 1 -type d)
EXTERNAL_PLUGINS=$(find src/plugins -type d -name ".git" | sed "s/\/.git//")

################################################################################
# Summary

echo "----------------------------------------------------------------"
echo "Make Distribution"
echo "Version: $VERSION ($VERSION_CODENAME)"
echo "Plugins: $EXTERNAL_PLUGINS"
if [ "$OPEN_SOURCE" == "yes" ]
then
    echo "Headers: OPEN SOURCE"
else
    echo "Headers: CLOSED SOURCE"
fi
echo "----------------------------------------------------------------"

################################################################################
# Warn if there are uncommitted changes (will not be taken into account)

GIT_STATUS="$(git status --porcelain -- $(sed 's/^./:!&/' <<< $EXTERNAL_PLUGINS))"
if [ "" != "$GIT_STATUS" ]; then
  echo "WARNING: uncommitted changes will be IGNORED when making archive:"
  echo "$GIT_STATUS" | sed 's/^/  /'
  echo "----------------------------------------------------------------"
fi

################################################################################
# Prepare Archive

git archive HEAD -o $FRAMAC_TAR --prefix "$FRAMAC/"

################################################################################
# Add external plugin to archive

if [ "" != "$EXTERNAL_PLUGINS" ]
then
  echo "Including external plugins:"
fi

for plugin in $EXTERNAL_PLUGINS
do
    echo "  $plugin"
    PLUGIN_TAR="$(basename $plugin).tar"
    git -C $plugin archive HEAD -o $PLUGIN_TAR --prefix "$FRAMAC/$plugin/"
    $TAR --concatenate --file=$FRAMAC_TAR "$plugin/$PLUGIN_TAR"
    rm -rf "$plugin/$PLUGIN_TAR"
done

if [ "" != "$EXTERNAL_PLUGINS" ]
then
  echo "----------------------------------------------------------------"
fi


################################################################################
# Prepare header spec

echo "Preparing headers..."

HEADER_SPEC="header-spec.txt"

git ls-files |\
git check-attr --stdin export-ignore |\
grep -v "export-ignore: set" | awk -F ': ' '{print $1}' |\
git check-attr --stdin header_spec > $HEADER_SPEC

for plugin in $EXTERNAL_PLUGINS ; do
  git -C $plugin ls-files |\
  git -C $plugin check-attr --stdin export-ignore |\
  grep -v "export-ignore: set" | awk -F ': ' '{print $1}' |\
  git -C $plugin check-attr --stdin header_spec |\
  xargs -n3 printf "$plugin/%s %s %s\n" >> $HEADER_SPEC
done

################################################################################
# Build option for check

# Frama-C is checked in open-source mode
CHECK_HEADER_OPT="-header-dirs headers/open-source"

# For plugins, either they can be open-source and we assume they have OS headers
# or they are closed-source
for plugin in $PLUGINS ; do
  if [ -d "$plugin/headers/open-source" ] ; then
    CHECK_HEADER_OPT="$CHECK_HEADER_OPT -header-dirs $plugin/headers/open-source"
  elif [ -d "$plugin/headers/closed-source" ] ; then
    CHECK_HEADER_OPT="$CHECK_HEADER_OPT -header-dirs $plugin/headers/closed-source"
  fi
done

################################################################################
# Build option for update

if [[ "$OPEN_SOURCE" == "yes" ]]; then
  HEADER_KIND="open-source"
else
  HEADER_KIND="closed-source"
fi

MAKE_HEADER_OPT="-header-dirs headers/$HEADER_KIND"

# Plugins can:
# - have both open and closed -> just use header kind
# - have only closed -> just use header kind, if it is open, build will fail
# - have only open -> just use open
for plugin in $PLUGINS ; do
  if [ -d "$plugin/headers" ] ; then
    if [ "$OPEN_SOURCE" == "yes" ] ; then
      MAKE_HEADER_OPT="$MAKE_HEADER_OPT -header-dirs $plugin/headers/open-source"
    else
      if [ ! -d "$plugin/headers/closed-source" ] ; then
        MAKE_HEADER_OPT="$MAKE_HEADER_OPT -header-dirs $plugin/headers/open-source"
      else
        MAKE_HEADER_OPT="$MAKE_HEADER_OPT -header-dirs $plugin/headers/closed-source"
      fi
    fi
  fi
done

################################################################################
# Headers

echo "Make headers..."

TMP_DIR=$(mktemp -d)
$TAR xf $FRAMAC_TAR -C $TMP_DIR

# Check
$HDRCK $CHECK_HEADER_OPT -spec-format="3-fields-by-line" -C "$TMP_DIR/$FRAMAC" $HEADER_SPEC
# Update
$HDRCK -update $MAKE_HEADER_OPT -spec-format="3-fields-by-line" -C "$TMP_DIR/$FRAMAC" $HEADER_SPEC

################################################################################
# Sanity check

if [ "$OPEN_SOURCE" == "yes" ] ; then
  OUT=$(grep -Iir "Contact CEA LIST for licensing." $TMP_DIR | grep -v "headers/" | grep -v "dev/make-distrib.sh")
  if [ "$?" == "0" ]; then
    echo "Looks like there are some files containing undetected closed source licences"
    exit 1
  fi
fi

################################################################################
# Finalize archive

echo "Finalizing archive..."

echo $VERSION_SAFE > $TMP_DIR/$FRAMAC/VERSION
echo $VERSION_CODENAME > $TMP_DIR/$FRAMAC/VERSION_CODENAME

DATE="$(date +%F)"

$TAR czf $FRAMAC_TAR.gz -C $TMP_DIR $FRAMAC \
  --numeric-owner --owner=0 --group=0 --sort=name --mode='a+rw' \
  --mtime="$DATE Z"

if [[ "$CI_LINK" == "yes" ]]; then
  ln $FRAMAC_TAR.gz "frama-c.tar.gz"
fi

################################################################################
# Cleaning

rm -rf $HEADER_SPEC
rm -rf $FRAMAC_TAR
rm -rf $TMP_DIR

echo "Generated: $FRAMAC_TAR.gz"
echo "----------------------------------------------------------------"
