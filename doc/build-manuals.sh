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
ACSL_SUFFIX=$(grep acslversion acsl/version.tex | sed 's/.*{\([^{}\\]*\).*/\1/')
EACSL_SUFFIX=$(grep 'newcommand{\\eacsllangversion' ../src/plugins/e-acsl/doc/refman/main.tex | sed 's/.*{\([^{}\\]*\).*/\1/')
# sanity check
if [ "$EACSL_SUFFIX" = "" ]; then
    echo "error: could not retrive E-ACSL version from ../src/plugins/e-acsl/doc/refman/main.tex"
    exit 1
fi

build () {

    echo "##### Building $1"
    make -C $(dirname $1) $(basename $1) || \
         (echo "######### $1 failed" ; exit 1)
    echo "##### $1 done"
    # extract extension, add suffix, re-append extension
    MANUAL=${2%.*}-$3.${2##*.}
    cp -f $1 manuals/$MANUAL
    echo "##### $MANUAL copied"
    
}

EACSL_DOC=../src/plugins/e-acsl/doc

export -f build

# Note: The makefiles of ACSL/E-ACSL are not parallelizable when producing both
# acsl.pdf and acsl-implementation.pdf (race conditions in intermediary files,
# leading to non-deterministic errors).
# Therefore, we perform a second call to parellel for these files.
SHELL=(type -p bash) parallel --halt soon,fail=1 --csv build {1} {2} {3} ::: \
userman/userman.pdf,user-manual.pdf,$FC_SUFFIX \
developer/developer.pdf,plugin-development-guide.pdf,$FC_SUFFIX \
rte/main.pdf,rte-manual.pdf,$FC_SUFFIX \
aorai/main.pdf,aorai-manual.pdf,$FC_SUFFIX \
aorai/aorai-example.tgz,aorai-example.tgz,$FC_SUFFIX \
value/main.pdf,eva-manual.pdf,$FC_SUFFIX \
metrics/metrics.pdf,metrics-manual.pdf,$FC_SUFFIX \
../src/plugins/wp/doc/manual/wp.pdf,wp-manual.pdf,$FC_SUFFIX \
acsl/acsl-implementation.pdf,acsl-implementation.pdf,$FC_SUFFIX \
$EACSL_DOC/refman/e-acsl-implementation.pdf,e-acsl-implementation.pdf,$FC_SUFFIX \
$EACSL_DOC/userman/main.pdf,e-acsl-manual.pdf,$FC_SUFFIX \

SHELL=(type -p bash) parallel --halt soon,fail=1 --csv build {1} {2} {3} ::: \
acsl/acsl.pdf,acsl.pdf,$ACSL_SUFFIX \
$EACSL_DOC/refman/e-acsl.pdf,e-acsl.pdf,$EACSL_SUFFIX

# Sanity check: version differences between Frama-C, ACSL and E-ACSL
if [ "$ACSL_SUFFIX" != "$EACSL_SUFFIX" ]; then
    echo "WARNING: different versions for ACSL and E-ACSL manuals: $ACSL_SUFFIX versus $EACSL_SUFFIX"
fi
