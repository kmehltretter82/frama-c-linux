/* run.config
 NOFRAMAC: testing frama-c-script, not frama-c itself
 DEPS: for-find-fun2.c for-find-fun.c main.c main2.c main3.c
   EXECNOW: LOG GNUmakefile LOG make_template.res LOG make_template.err PTESTS_TESTING= %{bin:frama-c-script} -C @PTEST_DIR@ make-template result < %{dep:@PTEST_DIR@/make_template.input} > @PTEST_RESULT@/make_template.res 2> @PTEST_RESULT@/make_template.err
 DEPS: main2.c main3.c main.c
   EXECNOW: LOG list_files.res LOG list_files.err %{bin:frama-c-script} list-files %{dep:@PTEST_DIR@/list_files.json} > @PTEST_RESULT@/list_files.res 2> @PTEST_RESULT@/list_files.err
 DEPS: for-find-fun2.c for-find-fun.c for-list-functions.c main2.c main3.c main.c make-wrapper2.c make-wrapper3.c make-wrapper.c
   EXECNOW: LOG find_fun1.res LOG find_fun1.err %{bin:frama-c-script} find-fun main2 @PTEST_DIR@ > @PTEST_RESULT@/find_fun1.res 2> @PTEST_RESULT@/find_fun1.err
   EXECNOW: LOG find_fun2.res LOG find_fun2.err %{bin:frama-c-script} find-fun main3 @PTEST_DIR@ > @PTEST_RESULT@/find_fun2.res 2> @PTEST_RESULT@/find_fun2.err
   EXECNOW: LOG find_fun3.res LOG find_fun3.err %{bin:frama-c-script} find-fun false_positive @PTEST_DIR@ > @PTEST_RESULT@/find_fun3.res 2> @PTEST_RESULT@/find_fun3.err
 DEPS:
   EXECNOW: LOG list_functions.res LOG list_functions.err %{bin:frama-c-script} list-functions %{dep:@PTEST_DIR@/for-find-fun2.c} %{dep:@PTEST_DIR@/for-list-functions.c} > @PTEST_RESULT@/list_functions.res 2> @PTEST_RESULT@/list_functions.err
   EXECNOW: LOG list_functions2.res LOG list_functions2.err LOG list_functions2.json %{bin:frama-c-script} list-functions %{dep:@PTEST_DIR@/for-find-fun2.c} %{dep:@PTEST_DIR@/for-list-functions.c -list-functions-declarations} -list-functions-output @PTEST_RESULT@/list_functions2.json -list-functions-debug 1 > @PTEST_RESULT@/list_functions2.res 2> @PTEST_RESULT@/list_functions2.err
 */



void main() {

}
// NB: Dependency to ./share directory where are script files used by %{bin:frama-c-script} is implicit with `dune` testing.
