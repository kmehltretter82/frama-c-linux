#!/bin/sh

BASE=$1

EXE_FILE=$BASE.byte
RES_FILE=result/$BASE.res.log
ERR_FILE=result/$BASE.err.log

make -s $EXE_FILE

CMD="$EXE_FILE -deps $BASE.c"

echo "$CMD"
#echo "RES = $RES_FILE"
#echo "ERR = $ERR_FILE"

$CMD > $RES_FILE 2> $ERR_FILE
