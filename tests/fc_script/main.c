/* run.config
   NOFRAMAC: testing frama-c-script, not frama-c itself
   DEPS: for-find-fun2.c for-find-fun.c main.c main2.c main3.c
   EXECNOW: LOG GNUmakefile LOG make_template.res LOG make_template.err PTESTS_TESTING= %{bin:frama-c-script} make-template . < %{dep:make_template.input} > make_template.res 2> make_template.err
   EXECNOW: LOG list_files.res LOG list_files.err %{bin:frama-c-script} list-files %{dep:list_files.json} > list_files.res 2> list_files.err
   EXECNOW: LOG flamegraph.html LOG flamegraph.res LOG flamegraph.err NOGUI=1 %{bin:frama-c-script} flamegraph %{dep:flamegraph.txt} . > flamegraph.res 2> flamegraph.err && rm -f flamegraph.svg
   EXECNOW: LOG find_fun1.res LOG find_fun1.err %{bin:frama-c-script} find-fun main2 . > find_fun1.res 2> find_fun1.err
   EXECNOW: LOG find_fun2.res LOG find_fun2.err %{bin:frama-c-script} find-fun main3 . > find_fun2.res 2> find_fun2.err
   EXECNOW: LOG find_fun3.res LOG find_fun3.err %{bin:frama-c-script} find-fun false_positive . > find_fun3.res 2> find_fun3.err
 */

void main() {

}
