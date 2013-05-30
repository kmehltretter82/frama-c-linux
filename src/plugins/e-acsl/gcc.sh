#!/bin/sh

gcc -std=c99 -pedantic -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin -o $1.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_bittree.c ./share/e-acsl/memory_model/e_acsl_mmodel.c $1 -lgmp && $1.out
