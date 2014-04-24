#!/bin/sh

#export SHARE=`frama-c -print-share-path`
export SHARE=./share

echo compiling $1
gcc -std=c99 -pedantic -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin -o $1.out $SHARE/e-acsl/e_acsl.c $SHARE/e-acsl/memory_model/e_acsl_bittree.c $SHARE/e-acsl/memory_model/e_acsl_mmodel.c $1 -lgmp

echo executing $1
time ./$1.out
