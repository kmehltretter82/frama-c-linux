#!/bin/sh

DIR=$1
IN=$2
if [ $# -gt 2 ]; then
    shift
    shift
    BUILTIN=$1
    ARGS=$@
fi

gcc -std=c99 -Wall -Wno-unused-function -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $BUILTIN -o ./tests/$DIR/result/gen_$IN.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_bittree.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/$DIR/result/gen_$IN.c -lgmp && ./tests/$DIR/result/gen_$IN.out $ARGS

# gcc -std=c99 -Wall -Wno-unused-function -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $BUILTIN -o ./tests/$DIR/result/gen_$IN.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_list.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/$DIR/result/gen_$IN.c -lgmp && ./tests/$DIR/result/gen_$IN.out $ARGS

# gcc -std=c99 -Wall -Wno-unused-function -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $BUILTIN -o ./tests/$DIR/result/gen_$IN.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_splay_tree.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/$DIR/result/gen_$IN.c -lgmp && ./tests/$DIR/result/gen_$IN.out $ARGS

# gcc -std=c99 -Wall -Wno-unused-function -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $BUILTIN -o ./tests/$DIR/result/gen_$IN.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_tree.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/$DIR/result/gen_$IN.c -lgmp && ./tests/$DIR/result/gen_$IN.out $ARGS
