#!/bin/sh
IN=$1
if [ $# -gt 1 ]; then
    shift;
    BUILTIN=$1
    shift;
    ARGS=$@
fi

gcc -std=c99 -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $BUILTIN -o ./tests/e-acsl-runtime/result/gen_$IN.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_bittree.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/e-acsl-runtime/result/gen_$IN.c -lgmp && ./tests/e-acsl-runtime/result/gen_$IN.out $ARGS

gcc -std=c99 -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $BUILTIN -o ./tests/e-acsl-runtime/result/gen_$IN.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_list.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/e-acsl-runtime/result/gen_$IN.c -lgmp && ./tests/e-acsl-runtime/result/gen_$IN.out $ARGS

gcc -std=c99 -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $BUILTIN -o ./tests/e-acsl-runtime/result/gen_$IN.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_splay_tree.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/e-acsl-runtime/result/gen_$IN.c -lgmp && ./tests/e-acsl-runtime/result/gen_$IN.out $ARGS

gcc -std=c99 -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $BUILTIN -o ./tests/e-acsl-runtime/result/gen_$IN.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_tree.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/e-acsl-runtime/result/gen_$IN.c -lgmp && ./tests/e-acsl-runtime/result/gen_$IN.out $ARGS
