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

# This script is meant to be run in CI. In particular, it requires the
# following environment variables:
# - CI_COMMIT_BRANCH (GitLab variable): the branch the commit belongs to
# - DEFAULT (CI variable): the default branch configured in .gitlab-ci.yml
# - PUBLISH (CI variable): indicating publish mode in .gitlab-ci.yml
#
# It checks that:
# - we are not in publish mode,
# - we are running the release pipeline on the default branch,
# - the default branch is a stable branch with a name coherent with the version
# - the tag of the commit is coherent with the version number
# - the version in the Opam file is coherent with the version number
# - the manual version in the Opam file is coherent with the version number

##########################################################################

function exit_red {
  echo -e "\e[31m$1\e[0m"
  exit 1
}
function echo_green {
  echo -e "\e[32m$1\e[0m"
}

VERSION="$(cat VERSION)"
VERSION_SAFE="$(cat VERSION | sed 's/~/-/')"
VERSION_OPAM=$(cat opam | grep "^version" | sed 's/version: \"\(.*\)\"/\1/')
MAN_VERSION_OPAM=$(cat opam | grep "^doc" | sed 's/.*\([1-9][0-9]\.[0-9].*\)\.pdf"/\1/')
TAG="$(git describe --tag)"
CODENAME="$(cat VERSION_CODENAME)"
LOWER_CODENAME="$(echo "$CODENAME" | tr '[:upper:]' '[:lower:]')"

if [[ "$PUBLISH" == "no" ]] ; then
  echo_green "We are not in publish mode"
else
  exit_red   "PUBLISH MODE DETECTED"
fi

if [[ "$DEFAULT" == "$CI_COMMIT_BRANCH" ]] ; then
  echo_green "The branch is the default branch"
else
  exit_red   "THIS BRANCH ($CI_COMMIT_BRANCH) IS NOT THE DEFAULT ($DEFAULT)"
fi

if [[ "$DEFAULT" == "stable/$LOWER_CODENAME" ]] ; then
  echo_green "The default branch is stable"
else
  exit_red   "$DEFAULT IS NOT A STABLE BRANCH"
fi

if [[ "$TAG" == "$VERSION_SAFE" ]] ; then
  echo_green "Git tag and version are consistent"
else
  exit_red   "GIT TAG $TAG IS NOT CONSISTENT WITH (SAFE) VERSION $VERSION_SAFE"
fi

if [[ "$VERSION" == "$VERSION_OPAM" ]] ; then
  echo_green "Opam version and version are consistent"
else
  exit_red   "VERSION $VERSION AND OPAM VERSION $VERSION_OPAM ARE NOT CONSISTENT"
fi

if [[ "$MAN_VERSION_OPAM" == "$VERSION_SAFE-$CODENAME" ]] ; then
  echo_green "Opam manual version and version are consistent"
else
  exit_red   "OPAM MANUAL VERSION $MAN_VERSION_OPAM AND VERSION $VERSION_SAFE-$CODENAME ARE NOT CONSISTENT"
fi
