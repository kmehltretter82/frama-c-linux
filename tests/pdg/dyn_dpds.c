/* run.config
   EXECNOW: make -s @PTEST_DIR@/@PTEST_NAME@.cmxs
   OPT: -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs -eva-show-progress -deps -journal-disable -pdg-print -pdg-verbose 2
*/


/*
   To have a look at the dot PDG :
   bin/toplevel.byte -deps -pdg-dot pdg -eva-show-progress -fct-pdg main @PTEST_DIR@/@PTEST_NAME@.c ;
   zgrviewer pdg.main.dot

   or use @PTEST_DIR@/@PTEST_NAME@.ml to test the dynamic dependencies.
*/

int G;

int main (int a, int b, int c) {
  int x;
  int * p ;
  x = a + b;
  p = &x;
  if (c < 0) {
    x = -x;
    //@assert (*p > G);
  }
  return x;
}
