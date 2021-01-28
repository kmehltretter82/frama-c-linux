/* run.config
   NOFRAMAC: testing frama-c-script, not frama-c itself
<<<<<<< HEAD
   DEPS: for-find-fun2.c for-find-fun.c main.c main2.c main3.c
   EXECNOW: LOG GNUmakefile LOG make_template.res LOG make_template.err PTESTS_TESTING= %{bin:frama-c-script} make-template . < %{dep:make_template.input} > make_template.res 2> make_template.err
   EXECNOW: LOG list_files.res LOG list_files.err %{bin:frama-c-script} list-files %{dep:list_files.json} > list_files.res 2> list_files.err
   EXECNOW: LOG flamegraph.html LOG flamegraph.res LOG flamegraph.err NOGUI=1 %{bin:frama-c-script} flamegraph %{dep:flamegraph.txt} . > flamegraph.res 2> flamegraph.err && rm -f flamegraph.svg
   EXECNOW: LOG find_fun1.res LOG find_fun1.err %{bin:frama-c-script} find-fun main2 . > find_fun1.res 2> find_fun1.err
   EXECNOW: LOG find_fun2.res LOG find_fun2.err %{bin:frama-c-script} find-fun main3 . > find_fun2.res 2> find_fun2.err
   EXECNOW: LOG find_fun3.res LOG find_fun3.err %{bin:frama-c-script} find-fun false_positive . > find_fun3.res 2> find_fun3.err
||||||| ac7807782d
   EXECNOW: LOG GNUmakefile LOG make_template.res LOG make_template.err cd @PTEST_DIR@ && PTESTS_TESTING= ../../bin/frama-c-script make-template result < make_template.input > result/make_template.res 2> result/make_template.err
   EXECNOW: LOG list_files.res LOG list_files.err bin/frama-c-script list-files @PTEST_DIR@/list_files.json > @PTEST_DIR@/result/list_files.res 2> @PTEST_DIR@/result/list_files.err
   EXECNOW: LOG flamegraph.html LOG flamegraph.res LOG flamegraph.err NOGUI=1 bin/frama-c-script flamegraph @PTEST_DIR@/flamegraph.txt @PTEST_DIR@/result > @PTEST_DIR@/result/flamegraph.res 2> @PTEST_DIR@/result/flamegraph.err && rm -f @PTEST_DIR@/result/flamegraph.svg
   EXECNOW: LOG find_fun1.res LOG find_fun1.err bin/frama-c-script find-fun main2 @PTEST_DIR@ > @PTEST_DIR@/result/find_fun1.res 2> @PTEST_DIR@/result/find_fun1.err
   EXECNOW: LOG find_fun2.res LOG find_fun2.err bin/frama-c-script find-fun main3 @PTEST_DIR@ > @PTEST_DIR@/result/find_fun2.res 2> @PTEST_DIR@/result/find_fun2.err
   EXECNOW: LOG find_fun3.res LOG find_fun3.err bin/frama-c-script find-fun false_positive @PTEST_DIR@ > @PTEST_DIR@/result/find_fun3.res 2> @PTEST_DIR@/result/find_fun3.err
=======
   EXECNOW: LOG GNUmakefile LOG make_template.res LOG make_template.err cd @PTEST_DIR@ && PTESTS_TESTING= ../../bin/frama-c-script make-template result < make_template.input > result/make_template.res 2> result/make_template.err
   EXECNOW: LOG list_files.res LOG list_files.err bin/frama-c-script list-files @PTEST_DIR@/list_files.json > @PTEST_DIR@/result/list_files.res 2> @PTEST_DIR@/result/list_files.err
   EXECNOW: LOG find_fun1.res LOG find_fun1.err bin/frama-c-script find-fun main2 @PTEST_DIR@ > @PTEST_DIR@/result/find_fun1.res 2> @PTEST_DIR@/result/find_fun1.err
   EXECNOW: LOG find_fun2.res LOG find_fun2.err bin/frama-c-script find-fun main3 @PTEST_DIR@ > @PTEST_DIR@/result/find_fun2.res 2> @PTEST_DIR@/result/find_fun2.err
   EXECNOW: LOG find_fun3.res LOG find_fun3.err bin/frama-c-script find-fun false_positive @PTEST_DIR@ > @PTEST_DIR@/result/find_fun3.res 2> @PTEST_DIR@/result/find_fun3.err
>>>>>>> origin/master
 */

void main() {

}
