/* run.config
   NOFRAMAC: testing frama-c-script, not frama-c itself
   EXECNOW: LOG GNUmakefile LOG make_template.res LOG make_template.err cd @PTEST_DIR@ && PTESTS_TESTING= ../../bin/frama-c-script make-template result < make_template.input > result/make_template.res 2> result/make_template.err
   EXECNOW: LOG list_files.res LOG list_files.err bin/frama-c-script list-files @PTEST_DIR@/list_files.json > list_files.res 2> list_files.err
   EXECNOW: LOG flamegraph.html LOG flamegraph.res LOG flamegraph.err NOGUI=1 bin/frama-c-script flamegraph @PTEST_DIR@/flamegraph.txt @PTEST_DIR@/result > flamegraph.res 2> flamegraph.err && rm -f flamegraph.svg
   EXECNOW: LOG find_fun1.res LOG find_fun1.err bin/frama-c-script find-fun main2 @PTEST_DIR@ > find_fun1.res 2> find_fun1.err
   EXECNOW: LOG find_fun2.res LOG find_fun2.err bin/frama-c-script find-fun main3 @PTEST_DIR@ > find_fun2.res 2> find_fun2.err
   EXECNOW: LOG find_fun3.res LOG find_fun3.err bin/frama-c-script find-fun false_positive @PTEST_DIR@ > find_fun3.res 2> find_fun3.err
 */

void main() {

}
