/* run.config
NOFRAMAC:
EXECNOW: LOG @PTEST_NAME@.res.0.log.txt BIN @PTEST_NAME@.sav @frama-c@ -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya @PTEST_FILE@ -save @PTEST_DIR@/result/@PTEST_NAME@.sav > @PTEST_DIR@/result/@PTEST_NAME@.res.0.log.txt
EXECNOW: LOG @PTEST_NAME@.res.1.log.txt @frama-c@ -load @PTEST_DIR@/result/@PTEST_NAME@.sav -then-on aorai -eva > @PTEST_DIR@/result/@PTEST_NAME@.res.1.log.txt
*/
/* run.config_prove
DONTRUN:
*/

void f () { }

int main () {
f();
Frama_C_show_aorai_state();
return 0;
}
