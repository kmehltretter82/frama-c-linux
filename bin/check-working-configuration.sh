#!/bin/bash -eu

# Displays the current working configuration of OCaml dependencies of Frama-C,
# comparing them with the one in `known_working_configuration.md`.

if ! type "opam" > /dev/null; then
    opam="<none>"
else
    opam="$(opam --version)"
fi

if ! type "ocaml" > /dev/null; then
    ocaml="<none>"
else
    ocaml=$(ocaml -vnum)
fi

version_via_opam() {
    v=$(opam info -f version "$1" 2>/dev/null)
    if [ "$v" = "" ]; then
        echo "<none>"
    else
        echo $v
    fi
}

version_via_ocamlfind() {
    v=$(ocamlfind query -format "$1" 2>/dev/null)
    if [ "$v" = "" ]; then
        echo "<none>"
    else
        echo $v
    fi
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
kwc="$SCRIPT_DIR/../known_working_configuration.md"

packages=$(grep '^- [^ ]*\.' "$kwc" | sed 's/^- //' | sed 's/ .*//')

bold=$(tput bold)
normal=$(tput sgr0)

has_any_diffs=0
# Check OCaml version separately (not same syntax as the packages)
working_ocaml=$(grep "\- OCaml " "$kwc" | sed 's/.*OCaml //')
if [ "$working_ocaml" != "$ocaml" ]; then
    echo -n "warning: OCaml ${bold}${ocaml}${normal} installed, "
    echo "expected ${bold}${working_ocaml}${normal}"
    has_any_diffs=1
fi

all_packages=""
for package in $packages; do
    name=${package%%.*}
    all_packages+=" $package"
    working_version=$(echo $package | sed 's/^[^.]*\.//')
    if [ "$opam" != "<none>" ]; then
        actual_version=$(version_via_opam $name)
    elif [ "$ocamlfind" != "<none>" ]; then
        actual_version=$(version_via_ocamlfind $name)
    else
        echo "error: neither opam nor ocamlfind found."
        exit 1
    fi
    if [ "$working_version" != "$actual_version" ]; then
        has_any_diffs=1
        echo -n "warning: $name ${bold}${actual_version}${normal} installed, "
        echo "expected ${bold}${working_version}${normal}"
    fi
done

echo "All packages checked."
if [ $has_any_diffs -ne 0 ]; then
    echo "Useful commands:"
    echo "    opam switch create ${working_ocaml}"
    echo "    opam install depext"
    echo "    opam depext --install$all_packages"
    echo "    rm -f ~/.why3.conf && why3 config --full-config"
fi
