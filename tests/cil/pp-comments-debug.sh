#!/bin/sh

CFILE=$1
OUT=$2
echo '# 1 "comments_debug.c"' > $2
cat $1 >> $2
