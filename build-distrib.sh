#! /usr/bin/bash

if   [[ $# > 1 ]] ; then
  echo "usage: $0 [ configuration_file ]"
  exit 1
elif [[ $# = 1 ]] ; then
  source $1
fi

VERSION=${VERSION:-$(cat VERSION)}
CODENAME=${CODENAME:-$(cat VERSION_CODENAME)}

FRAMAC=frama-c-$VERSION-$CODENAME

FPATH=$FRAMAC/

git archive --format=tar --prefix $FPATH HEAD > $FRAMAC.tar

TRANSFO="s,^,$FPATH,"
tar rf $FRAMAC.tar configure --transform $TRANSFO
