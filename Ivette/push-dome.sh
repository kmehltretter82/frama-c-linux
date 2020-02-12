#!/bin/sh

DOME=$1
BRANCH=$2

if [ "$DOME" == "" ] || [ "$BRANCH" == "" ]
then
    echo "Usage: push-electron.sh <dome-clone-dir> <new-branch>"
    exit 1
fi

git -C $DOME remote -v | grep -q dome/electron.git

if [ "$?" != "0" ]
then
    echo "Clone of dome/electron not found in '$DOME'"
    exit 1
fi

echo "Push updates to $DOME#$BRANCH"

git -C $DOME checkout -B $BRANCH

FILES=$(cd src/dome ; git ls-files)

for f in $FILES
do
    cp -f src/dome/$f $DOME/$f
done

git -C $DOME commit -a
