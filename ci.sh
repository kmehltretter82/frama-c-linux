#!/usr/bin/env bash

set -euxo pipefail

if [[ $# != 1 ]];
then
  cat <<EOF
usage: $0 <plugin> | all
  $0 all run CI on all plugins
  $0 <plugin_name> run CI only on this plugins
EOF
  exit 2
fi

# all plugins to check
all_plugins=(Volatile)
if [[ "$1" = "all" ]];
then plugins=("${all_plugins[@]}")
else plugins=("$1")
fi

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

curdir="$(dirname "$(readlink -f "$0")")"
git_current_branch="$(git branch --show-current)"
: "${git_current_branch:=${CI_COMMIT_BRANCH:-}}"
echo "currently on branch $git_current_branch"
[[ -n $git_current_branch ]]
plugin_repo=

cleanup () {
  if [[ -n $plugin_repo ]];
  then rm -rf "$plugin_repo"
  fi
}

trap cleanup EXIT

do_plugin () {
  OPTS="--arg frama-c-repo $curdir"

  plugin=$1
  cd "$(mktemp -d)"
  # the hash of the derivation depends on the directory name
  mkdir "$plugin"
  cd "$plugin"
  plugin_repo="$(readlink -f .)"
  plugin_url="git@git.frama-c.com:frama-c/$plugin.git"

  plugin_branch="$(get_matching_branch "$plugin_url" "$git_current_branch")"
  echo "using branch $plugin_branch of $plugin_url"
  git clone --depth=1 --branch="$plugin_branch" "$plugin_url" .

  declare -A deps=( )
  declare -A dirs=( )

  if [[ -f "./nix/dependencies" ]]; then
    while read -r var value; do
      deps[$var]=$value
    done < "./nix/dependencies"

    for repo in ${!deps[@]}; do
      # the hash of the derivation depends on the directory name
      mkdir "../$repo"
      directory="$(readlink -f ../$repo)"
      dirs[$repo]=$directory

      url=${deps[$repo]}
      branch="$(get_matching_branch "$url" "$git_current_branch")"
      echo "using branch $branch of $repo at $directory"
      # clone
      git clone --depth=1 --branch="$branch" "$url" "$directory"

      OPTS="$OPTS --arg $repo $directory"
    done
  fi

  # run the build
  nix-build --no-out-link "./nix/pkgs.nix" $OPTS -A ocaml-ng.ocamlPackages_4_12."$plugin"

  cd "$curdir"

  for repo in ${!dirs[@]}; do
    if [[ -n ${dirs[$repo]} ]];
    then rm -rf "${dirs[$repo]}"
    fi
  done

  rm -rf "$plugin_repo"
}

for plugin in "${plugins[@]}"; do
  do_plugin $plugin
done
