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

# Note:
#
# While this script can be run locally, it is meant to run in the Frama-C CI.
# Thus, it expects to be run from the root of the Frama-C directory and that
# some CI artifacts are available. Namely:
#   - 'frama-c.tar.gz'
#   - 'api' directory (with api archives inside)
#   - 'manuals' directory (with all manuals incl. acsl + version text files)
# Availability of the files is checked when the script starts. The script also
# checks that:
#   - the version is stable (VERSION file does not contain '+dev')
#   - the commit is tagged with the version (if it contains ~, replaced by -)
#   - releases/<VERSION_MAJOR>.<VERSION_MINOR>.md exists
# The script generates the following directories:
#   - wiki (for the public Frama-C instance)
#   - website
#   - opam-repository
#   - release-data.json
# with the correct tree for generated files.

##########################################################################
# Check binaries

set -eu

function echo_red {
  echo -e "\e[31m$1\e[0m"
}
function echo_green {
  echo -e "\e[32m$1\e[0m"
}

function show_step {
  echo ""
  echo "### $1"
  echo ""
}

show_step "Checking binaries availability"

if ! command -v git-lfs >/dev/null 2>/dev/null; then
  echo_red "git-lfs is required"
  exit 127
fi

# grep needs to be installed
if ! command -v grep --version >/dev/null 2>/dev/null; then
  echo_red "grep is required"
  exit 127
fi

MANUALS_DIR="./manuals"
API_DIR="./api"

FRAMAC_COM_DOWNLOAD="https://www.frama-c.com/download"

##########################################################################
# Check stable or beta and build names

show_step "Checking version"

VERSION="$(cat VERSION)"
VERSION_SAFE="$(cat VERSION | sed 's/~/-/')"
VERSION_MODIFIER=$(sed VERSION -e s/[0-9.]*\\\(.*\\\)/\\1/)
VERSION_MAJOR=$(sed VERSION -e s/\\\([0-9]*\\\).[0-9]*.*/\\1/)
VERSION_MINOR=$(sed VERSION -e s/[0-9]*.\\\([0-9]*\\\).*/\\1/)
TAG="$(git describe --tag)"
CODENAME="$(cat VERSION_CODENAME)"
LOWER_CODENAME="$(echo "$CODENAME" | tr '[:upper:]' '[:lower:]')"
VERSION_AND_CODENAME="${VERSION_SAFE}-${CODENAME}"

if [ "$VERSION_MINOR" != 0 ]; then
  # We compare new minor to previous minor
  PREVIOUS="$VERSION_MAJOR.$((VERSION_MINOR - 1))"
  PREVIOUS_TAG="$PREVIOUS"
else
  # We compare new major to previous major, the exact previous version is not
  # of interest for a new major version
  PREVIOUS="$((VERSION_MAJOR - 1))"
  PREVIOUS_TAG="$PREVIOUS.0"
fi
PREVIOUS_NAME=$(git show "$PREVIOUS_TAG":VERSION_CODENAME)

if [ "$VERSION_MODIFIER" == "+dev" ]; then
  echo "Development version ($VERSION)"
  echo_red "Aborting"
  exit 2
fi

if [ "$VERSION_SAFE" != "$TAG" ]; then
  echo "The current commit is not tagged with the current version:"
  echo "Frama-C Version: $VERSION_SAFE"
  echo "Frama-C Tag    : $TAG"
  echo_red "Aborting"
  exit 2
fi

if test -n "$VERSION_MODIFIER"; then
  FINAL_RELEASE=no
else
  FINAL_RELEASE=yes
fi

echo "Ready to build release: Frama-C $VERSION - $CODENAME"
echo "MAJOR: $VERSION_MAJOR"
echo "MINOR: $VERSION_MINOR"
echo "FINAL: $FINAL_RELEASE"

##########################################################################
# Check input files

function prepare_file {
  echo -n "Searching for '$1' ... "
  if [ ! -f "$1" ]; then
    echo_red "FAILED (aborting)"
    exit 2
  fi
  echo_green "OK"
  chmod 644 "$1"
}

show_step "Searching for a Frama-C source archive"

TARGZ_BASE="frama-c.tar.gz"
TARGZ_GENERIC="frama-c-source-dist.tar.gz"
TARGZ_VERSION="frama-c-$VERSION_SAFE-$CODENAME.tar.gz"
prepare_file $TARGZ_BASE

show_step "Searching for a Frama-C API archive"

API_FILES=(
  frama-c
  frama-c-server
)

for file in "${API_FILES[@]}"; do
  prepare_file "$API_DIR/$file-api.tar.gz"
done

show_step "Searching for manuals"

MANUALS=(
  "acsl"
  "acsl-implementation"
  "aorai-manual"
  "e-acsl"
  "e-acsl-implementation"
  "e-acsl-manual"
  "eva-manual"
  "metrics-manual"
  "plugin-development-guide"
  "rte-manual"
  "user-manual"
  "wp-manual"
)

COMPANIONS=(
  "aorai-example"
  "hello"
)

for manual in "${MANUALS[@]}"; do
  prepare_file "$MANUALS_DIR/$manual.pdf"
done

for companion in "${COMPANIONS[@]}"; do
  prepare_file "$MANUALS_DIR/$companion.tar.gz"
done

prepare_file "$MANUALS_DIR/acsl-version.txt"
ACSL_VERSION=$(cat "$MANUALS_DIR/acsl-version.txt")
prepare_file "$MANUALS_DIR/e-acsl-version.txt"
EACSL_VERSION=$(cat "$MANUALS_DIR/e-acsl-version.txt")

show_step "Searching for changes"

CHANGES="releases/$VERSION_MAJOR.$VERSION_MINOR.md"
prepare_file "$CHANGES"

##########################################################################
# File copy

function generic_name {
  if   [ "$1" == "frama-c" ]; then echo "frama-c-source-dist"
  elif [ "$1" == "acsl" ]; then echo "acsl"
  elif [ "$1" == "e-acsl" ]; then echo "e-acsl"
  elif [[ $1 =~ ^e-acsl.*$ ]]; then echo "$1"
  else echo "frama-c-$1"
  fi
}
function version_name {
  if   [ "$1" == "acsl" ]; then echo "acsl-$ACSL_VERSION"
  elif [ "$1" == "e-acsl" ]; then echo "e-acsl-$EACSL_VERSION"
  else echo "$1-$VERSION_AND_CODENAME"
  fi
}

# For the 3 next functions
# $1 : name
# $2 : extension

function copy_manual_normal {
  if [ "$FINAL_RELEASE" = "yes" ]; then
    cp "$MANUALS_DIR/$1.$2" "$MANS_TARGET_DIR/$(generic_name "$1").$2"
  fi
  cp "$MANUALS_DIR/$1.$2" "$MANS_TARGET_DIR/$(version_name "$1").$2"
}

function copy_manual_e_acsl {
  EACSL_TARGET_DIR="$MANS_TARGET_DIR/e-acsl"
  if [ "$FINAL_RELEASE" = "yes" ]; then
    cp "$MANUALS_DIR/$1.$2" "$EACSL_TARGET_DIR/$(generic_name "$1").$2"
  fi
  cp "$MANUALS_DIR/$1.$2" "$EACSL_TARGET_DIR/$(version_name "$1").$2"
}

function copy_api {
  if [ "$FINAL_RELEASE" = "yes" ]; then
    cp "$API_DIR/$1-api.$2" "$MANS_TARGET_DIR/$1-api.$2"
  fi
  cp "$API_DIR/$1-api.$2" "$MANS_TARGET_DIR/$1-$VERSION_AND_CODENAME-api.$2"
}

function copy_files {
  for manual in "${MANUALS[@]}"; do
    if [[ $manual =~ ^e-acsl.*$ ]]; then
      copy_manual_e_acsl "$manual" "pdf"
    else
      copy_manual_normal "$manual" "pdf"
    fi
  done
  for companion in "${COMPANIONS[@]}"; do
    copy_manual_normal "$companion" "tar.gz"
  done
  for api in "${API_FILES[@]}"; do
    copy_api "$api" "tar.gz"
  done

  # Eva has an old manual name that might be in use:
  if [ "$FINAL_RELEASE" = "yes" ]; then
    cp "$MANS_TARGET_DIR/frama-c-eva-manual.pdf" "$MANS_TARGET_DIR/frama-c-value-analysis.pdf"
  fi

  cp $TARGZ_BASE "$GZ_TARGET_DIR/$TARGZ_VERSION"
  if [ "$FINAL_RELEASE" = "yes" ]; then
    cp $TARGZ_BASE "$GZ_TARGET_DIR/$TARGZ_GENERIC"
  fi
}

##########################################################################
# Make opam

show_step "Building opam repository file"

OPAM_DIR="opam-repository"
OPAM_FC_DIR="$OPAM_DIR/packages/frama-c/frama-c.$VERSION"

mkdir -p $OPAM_DIR
mkdir -p $OPAM_FC_DIR

OPAM_VERSION="opam-version: \"2.0\""
if [ "$FINAL_RELEASE" = "yes" ]; then
  OPAM_VERSION_FIX="$OPAM_VERSION"
else
  OPAM_VERSION_FIX="$OPAM_VERSION\navailable: opam-version >= \"2.1.0\"\nflags: avoid-version"
fi

cat opam \
  | grep -v "^version\:" \
  | grep -v "^name\:" \
  | sed -e "s/$OPAM_VERSION/$OPAM_VERSION_FIX/" \
  > $OPAM_FC_DIR/opam

cat >>$OPAM_FC_DIR/opam << EOL

url {
  src: "$FRAMAC_COM_DOWNLOAD/$TARGZ_VERSION"
  checksum: "sha256=$(sha256sum $TARGZ_BASE | cut -d" " -f1)"
}
EOL

echo "Opam file built"

##########################################################################
# Make wiki

show_step "Building wiki"

WIKI_DIR="wiki"

mkdir -p $WIKI_DIR

echo "Download directory built"

WIKI_PAGE="$WIKI_DIR/Frama-C-${VERSION_AND_CODENAME}.md"

echo "# Frama-C release $VERSION ($CODENAME)" > $WIKI_PAGE
echo "## Sources" >> $WIKI_PAGE
echo "- [$TARGZ_VERSION]($FRAMAC_COM_DOWNLOAD/$TARGZ_VERSION)" >> $WIKI_PAGE
echo "" >> $WIKI_PAGE
echo "## Manuals" >> $WIKI_PAGE
for manual in "${MANUALS[@]}"; do
  if [[ $manual =~ ^e-acsl.*$ ]]; then
    DIR="$FRAMAC_COM_DOWNLOAD/e-acsl"
  else
    DIR="$FRAMAC_COM_DOWNLOAD"
  fi
  NAME=$(version_name $manual)
  echo "- [$manual]($DIR/$NAME.pdf)" >> $WIKI_PAGE
done
echo "" >> $WIKI_PAGE
echo "## Companion archives" >> $WIKI_PAGE
for archive in "${COMPANIONS[@]}"; do
  NAME=$(version_name "$archive")
  echo "- [$archive]($FRAMAC_COM_DOWNLOAD/$NAME.tar.gz)" >> $WIKI_PAGE
done
echo "" >> $WIKI_PAGE
echo "## Main changes" >> $WIKI_PAGE
sed 's/\(\#.*\)/##\1/' $CHANGES >> $WIKI_PAGE

echo "Wiki page built"

##########################################################################
# Make release

show_step "Building release json file"

JSON_DATA="release-data.json"

cat >$JSON_DATA <<EOL
{
  "name": "Frama-C $VERSION $CODENAME",
  "tag_name": "$VERSION_SAFE",
  "ref": "stable/$LOWER_CODENAME",
  "assets": {
    "links": [
      {
        "name": "API Documentation",
        "url": "https://frama-c.com/download/frama-c-$VERSION_AND_CODENAME-api.tar.gz",
        "link_type":"other"
      },
      {
        "name": "Server API Documentation",
        "url": "https://frama-c.com/download/frama-c-server-$VERSION_AND_CODENAME-api.tar.gz",
        "link_type":"other"
      },
      {
        "name": "Official source archive",
        "url": "https://frama-c.com/download/$TARGZ_VERSION",
        "link_type":"other"
      }
    ]
  },
EOL
echo "  \"description\": \"# Main changes since $PREVIOUS $PREVIOUS_NAME\n$(jq <"$CHANGES" --raw-input 'sub("^#";"##")' | jq --slurp 'join("\n")' | sed 's/^.//;s/.$//')\"" >> $JSON_DATA
echo "}" >> $JSON_DATA

echo "Release data file built"

##########################################################################
# Make website

show_step "Building website"

WEBSITE_DIR="./website"
WEBSITE_DL_DIR="$WEBSITE_DIR/download"
WEBSITE_INST_DIR="$WEBSITE_DIR/html/installations"
WEBSITE_EVENTS_DIR="$WEBSITE_DIR/_events"
WEBSITE_VERSIONS_DIR="$WEBSITE_DIR/_fc-versions"

mkdir -p $WEBSITE_DIR

# Downloads

mkdir -p $WEBSITE_DL_DIR
mkdir -p $WEBSITE_DL_DIR/e-acsl

GZ_TARGET_DIR=$WEBSITE_DL_DIR
MANS_TARGET_DIR=$WEBSITE_DL_DIR

copy_files

echo "Download directory built"

# Install

mkdir -p $WEBSITE_INST_DIR

INSTALL_WEBPAGE="$WEBSITE_INST_DIR/$LOWER_CODENAME.md"
EXT="$CODENAME (released on $(date +%Y-%m-%d))"

cat >$INSTALL_WEBPAGE <<EOL
---
layout: installation_page
version: $LOWER_CODENAME
title: Installation instructions for Frama-C $VERSION ($CODENAME)
---
EOL
sed ./INSTALL.md -e "s/^\(# Installing Frama-C\)$/\1 $EXT/" >>$INSTALL_WEBPAGE

echo "Installation file built"

# Event

mkdir -p $WEBSITE_EVENTS_DIR

TEXTUAL_VERSION="Frama-C $VERSION ($CODENAME)"
TEXTUAL_PREVIOUS="Frama-C $PREVIOUS ($PREVIOUS_NAME)"

if [ "$FINAL_RELEASE" = "no" ]; then
  EVENT_TITLE="Beta release of $TEXTUAL_VERSION"
else
  EVENT_TITLE="Release of $TEXTUAL_VERSION"
fi
VERSION_PAGE="/fc-versions/$LOWER_CODENAME.html"

EVENT_WEBPAGE="$WEBSITE_EVENTS_DIR/framac-$VERSION_SAFE.md"

cat >$EVENT_WEBPAGE <<EOL
---
layout: default
date: $(date +\"%d-%m-%Y\")
short_title: $TEXTUAL_VERSION
title: $EVENT_TITLE
link: /fc-versions/$LOWER_CODENAME.html
---

$TEXTUAL_VERSION is out. Download it [here]($VERSION_PAGE).

Main changes with respect to $TEXTUAL_PREVIOUS include:

EOL
sed 's/\(\#.*\)/###\1/' $CHANGES >>$EVENT_WEBPAGE

echo "Event file built"

# Version

mkdir -p $WEBSITE_VERSIONS_DIR
VERSION_WEBPAGE="$WEBSITE_DIR/_fc-versions/$LOWER_CODENAME.md"

if [ "$FINAL_RELEASE" = "no" ]; then
  ACSL_OR_BETA="beta: true"
else
  ACSL_VERSION_WEBSITE="$(echo $ACSL_VERSION | sed -n 's/1.\([0-9][0-9]\)/\1/p')"
  ACSL_OR_BETA="acsl: $ACSL_VERSION_WEBSITE"
fi

cat >$VERSION_WEBPAGE <<EOL
---
layout: version
number: $VERSION_MAJOR
name: $CODENAME
$ACSL_OR_BETA
releases:
- number: $VERSION_MINOR
  categories:
  - name: Frama-C v$VERSION $CODENAME
    files:
    - name: Source distribution
      link: /download/$TARGZ_VERSION
      help: Compilation instructions
      help_link: /html/installations/$LOWER_CODENAME.html
    - name: User manual
      link: /download/user-manual-$VERSION_AND_CODENAME.pdf
    - name: Plug-in development guide
      link: /download/plugin-development-guide-$VERSION_AND_CODENAME.pdf
      help: Hello plug-in tutorial archive
      help_link: /download/hello-$VERSION_AND_CODENAME.tar.gz
    - name: API Documentation
      link: /download/frama-c-$VERSION_AND_CODENAME-api.tar.gz
    - name: Server API Documentation
      link: /download/frama-c-server-$VERSION_AND_CODENAME-api.tar.gz
    - name: ACSL $ACSL_VERSION ($CODENAME implementation)
      link: /download/acsl-implementation-$VERSION_AND_CODENAME.pdf
  - name: Plug-in Manuals
    sort: true
    files:
    - name: Aoraï manual
      link: /download/aorai-manual-$VERSION_AND_CODENAME.pdf
      help: Aoraï example
      help_link: /download/aorai-example-$VERSION_AND_CODENAME.tar.gz
    - name: Metrics manual
      link: /download/metrics-manual-$VERSION_AND_CODENAME.pdf
    - name: Rte manual
      link: /download/rte-manual-$VERSION_AND_CODENAME.pdf
    - name: Eva manual
      link: /download/eva-manual-$VERSION_AND_CODENAME.pdf
    - name: WP manual
      link: /download/wp-manual-$VERSION_AND_CODENAME.pdf
    - name: E-ACSL manual
      link: /download/e-acsl/e-acsl-manual-$VERSION_AND_CODENAME.pdf
---
EOL

echo "Version file built"
