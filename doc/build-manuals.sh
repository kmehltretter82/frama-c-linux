#! /usr/bin/env bash

cd $(dirname $0)

usage () {
    echo "usage: $(basename $0) [help|clean|build] (default: build)"
}

if test $# -gt 1; then usage; exit 2; fi;

if test $# -eq 1; then
    case $1 in
        "help") usage; exit 0;;
        "clean") rm -f manuals/*.pdf; exit 0;;
        "build") ;;
        *) usage; exit 2;;
    esac
fi

set -e

if [ ! -e acsl ]; then
    echo "error: 'acsl' not in doc; clone git@github.com:acsl-language/acsl.git"
    exit 1
fi

mkdir -p manuals


FC_SUFFIX=$(cat ../VERSION)-$(cat ../VERSION_CODENAME)
ACSL_SUFFIX=$(grep acslversion acsl/version.tex | sed 's/.*{\([^{}].*\)}.*/\1/')

build () {

    echo "##### Building $1"
    make -C $(dirname $1) $(basename $1) || \
         (echo "######### $1 failed" ; exit 1)
    echo "##### $1 done"
    MANUAL=$(basename $2 .pdf)-$3.pdf
    cp -f $1 manuals/$MANUAL
    echo "##### $MANUAL copied"
    ln -srf manuals/$MANUAL manuals/$2
}

EACSL_DOC=../src/plugins/e-acsl/doc

export -f build
SHELL=(type -p bash) parallel -j 4 --csv build {1} {2} {3} ::: \
userman/userman.pdf,user-manual.pdf,$FC_SUFFIX \
developer/developer.pdf,plugin-development-guide.pdf,$FC_SUFFIX \
rte/main.pdf,rte-manual.pdf,$FC_SUFFIX \
aorai/main.pdf,aorai-manual.pdf,$FC_SUFFIX \
value/main.pdf,eva-manual.pdf,$FC_SUFFIX \
metrics/metrics.pdf,metrics-manual.pdf,$FC_SUFFIX \
../src/plugins/wp/doc/manual/wp.pdf,wp-manual.pdf,$FC_SUFFIX \
acsl/acsl-implementation.pdf,acsl-implementation.pdf,$FC_SUFFIX \
$EACSL_DOC/refman/e-acsl-implementation.pdf,e-acsl-implementation.pdf,$FC_SUFFIX \
$EACSL_DOC/userman/main.pdf,e-acsl-manual.pdf,$FC_SUFFIX \
acsl/acsl.pdf,acsl.pdf,$ACSL_SUFFIX \
$EACSL_DOC/refman/e-acsl.pdf,e-acsl.pdf,$ACSL_SUFFIX
