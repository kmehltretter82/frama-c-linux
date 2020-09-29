#!/bin/sh

LIBC=$(frama-c -print-share-path)/libc

for A in `find $LIBC -name "*.h" -printf "%P\n"`;
do
    if ! grep -q $A fc_libc.c ;
    then echo "#include \"$A"\";
    fi ;
done;

for A in `find $LIBC -name "*.c" -printf "%P\n"`;
do
    if ! grep -q $A $LIBC/__fc_runtime.c fc_libc.c ;
    then echo Not included implementation \'$A\';
    fi ;
done;
