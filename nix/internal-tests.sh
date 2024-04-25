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

# DEFAULT variable can be configured to indicate reference branch when the
# current branch does not exist in a plugin.
#
# OCAML must be set to the right version of OCAML (format: N_MM or N.MM)

set -euxo pipefail

if [ -z ${OCAML+x} ]; then
  echo "OCAML variable must be set to a version of OCaml"
  exit 2
fi

# Normalize version for Nix
OCAML=${OCAML/./_}

DEFAULT=${DEFAULT:-master}

# prints
# - "$2" if it is a branch name in remote $1,
# - else "$DEFAULT" if it is set and $DEFAULT is a branch name in remote $1,
# - else master
get_matching_branch () {
  if   git ls-remote --quiet --exit-code "$1" "$2" >/dev/null 2>/dev/null;
  then echo "$2"
  elif git ls-remote --quiet --exit-code "$1" "$DEFAULT" >/dev/null 2>/dev/null;
  then echo "$DEFAULT"
  else echo master
  fi
}

git_current_branch="$(git branch --show-current)"
: "${git_current_branch:=${CI_COMMIT_BRANCH:-}}"
echo "currently on branch $git_current_branch"

temporary="$(mktemp -d)"
callsite="$(pwd)"

cleanup () {
  cd "$callsite"
  if [[ -n $temporary ]];
  then rm -rf "$temporary"
  fi
  git worktree prune
}

trap cleanup EXIT

git worktree add "$temporary" "$(git rev-parse HEAD)"
cd "$temporary"
./nix/wp-cache.nix.sh

declare -A plugins=( )

if [[ ! -f "./nix/external-plugins.txt" ]]; then
  echo "NO ./nix/external-plugins.txt FOUND!"
  exit 2
fi

while read -r var value; do
  plugins[$var]=$value
done < "./nix/external-plugins.txt"

for plugin in ${!plugins[@]}; do
  repo=${plugins[$plugin]}
  branch="$(get_matching_branch "$repo" "$git_current_branch")"
  git clone --depth=1 --branch="$branch" "$repo" "src/plugins/$plugin"
done

nix-build --no-out-link "./nix/pkgs.nix" -A ocaml-ng.ocamlPackages_$OCAML.internal-tests
