/* run.config
   NOFRAMAC: testing frama-c-script, not frama-c itself
   EXECNOW: LOG GNUmakefile LOG make_template.res LOG make_template.err cd @PTEST_DIR@ && PTESTS_TESTING= ../../bin/frama-c-script make-template result < make_template.input > result/make_template.res 2> result/make_template.err
   EXECNOW: LOG list_files.res LOG list_files.err bin/frama-c-script list-files @PTEST_DIR@/list_files.json > @PTEST_DIR@/result/list_files.res 2> @PTEST_DIR@/result/list_files.err
   EXECNOW: LOG find_fun1.res LOG find_fun1.err bin/frama-c-script find-fun main2 @PTEST_DIR@ > @PTEST_DIR@/result/find_fun1.res 2> @PTEST_DIR@/result/find_fun1.err
   EXECNOW: LOG find_fun2.res LOG find_fun2.err bin/frama-c-script find-fun main3 @PTEST_DIR@ > @PTEST_DIR@/result/find_fun2.res 2> @PTEST_DIR@/result/find_fun2.err
   EXECNOW: LOG find_fun3.res LOG find_fun3.err bin/frama-c-script find-fun false_positive @PTEST_DIR@ > @PTEST_DIR@/result/find_fun3.res 2> @PTEST_DIR@/result/find_fun3.err
   EXECNOW: LOG list_functions.res LOG list_functions.err bin/frama-c-script list-functions @PTEST_DIR@/for-find-fun2.c @PTEST_DIR@/for-list-functions.c > @PTEST_DIR@/result/list_functions.res 2> @PTEST_DIR@/result/list_functions.err
   EXECNOW: LOG list_functions2.res LOG list_functions2.err LOG list_functions2.json bin/frama-c-script list-functions @PTEST_DIR@/for-find-fun2.c @PTEST_DIR@/for-list-functions.c -list-functions-declarations -list-functions-output @PTEST_DIR@/result/list_functions2.json -list-functions-debug 1 > @PTEST_DIR@/result/list_functions2.res 2> @PTEST_DIR@/result/list_functions2.err
 */

void main() {

}
