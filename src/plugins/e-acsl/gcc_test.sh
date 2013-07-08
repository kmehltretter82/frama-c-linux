#!/bin/sh
gcc -std=c99 -pedantic -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $2 -o ./tests/e-acsl-runtime/result/gen_$1.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_bittree.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/e-acsl-runtime/result/gen_$1.c -lgmp && ./tests/e-acsl-runtime/result/gen_$1.out

gcc -std=c99 -pedantic -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $2 -o ./tests/e-acsl-runtime/result/gen_$1.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_list.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/e-acsl-runtime/result/gen_$1.c -lgmp && ./tests/e-acsl-runtime/result/gen_$1.out

gcc -std=c99 -pedantic -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $2 -o ./tests/e-acsl-runtime/result/gen_$1.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_splay_tree.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/e-acsl-runtime/result/gen_$1.c -lgmp && ./tests/e-acsl-runtime/result/gen_$1.out

gcc -std=c99 -pedantic -Wall -Wno-long-long -Wno-attributes -Wno-unused-but-set-variable -fno-builtin $2 -o ./tests/e-acsl-runtime/result/gen_$1.out ./share/e-acsl/e_acsl.c ./share/e-acsl/memory_model/e_acsl_tree.c ./share/e-acsl/memory_model/e_acsl_mmodel.c ./tests/e-acsl-runtime/result/gen_$1.c -lgmp && ./tests/e-acsl-runtime/result/gen_$1.out
