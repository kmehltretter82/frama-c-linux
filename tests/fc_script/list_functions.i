/* run.config
 NOFRAMAC: testing frama-c-script, not frama-c itself

 DEPS: @PTEST_DEPS@ ./for-find-fun.c
 DEPS: @PTEST_DEPS@ ./for-find-fun2.c
 DEPS: @PTEST_DEPS@ ./for-list-functions.c
 DEPS: @PTEST_DEPS@ ./list_functions.i
 DEPS: @PTEST_DEPS@ ./main.c
 DEPS: @PTEST_DEPS@ ./main2.c
 DEPS: @PTEST_DEPS@ ./main3.c
 DEPS: @PTEST_DEPS@ ./make-wrapper.c
 DEPS: @PTEST_DEPS@ ./make-wrapper2.c
 DEPS: @PTEST_DEPS@ ./make-wrapper3.c

 DEPS: @PTEST_DEPS@ ./build-callgraph.i
 DEPS: @PTEST_DEPS@ ./recursions.i

   EXECNOW: LOG heuristic_list_functions.res LOG heuristic_list_functions.err PTESTS_TESTING=1 %{bin:frama-c-script} heuristic-list-functions true true @PTEST_DEPS@ > ./heuristic_list_functions.res 2> ./heuristic_list_functions.err
 */
