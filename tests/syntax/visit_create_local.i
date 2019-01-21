/* run.config
EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
OPT: -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs -then-on bidon -print
 */
void main() { int x,y;  x = y; }
