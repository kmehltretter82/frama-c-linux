#! /usr/bin/env bash

cd $(dirname $0)

set -e

build () {
    if test -z "$2" ; then export NAME="$1"; else export NAME="$2"; fi
    echo "##### Building $NAME"
    cd $1
    make $3 || (echo "######### $NAME failed" ; exit 1)
    make install
    echo "##### $NAME done"
    cd ..
}

mkdir -p manuals

build userman
build developer "Developer manual" developer.pdf

build rte
build aorai
build metrics
build value
if [ ! -e acsl ]; then
    echo "error: 'acsl' not in doc; clone git@github.com:acsl-language/acsl.git"
    exit 1
fi
build acsl "ACSL manuals" all

cd ../src/plugins/wp/doc/

build manual WP

cd ../../e-acsl/doc

build userman "E-ACSL userman"

build refman "E-ACSL reference"

cd ../../../..
