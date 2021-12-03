/* run.config
   EXECNOW: LOG callbacks_initial.res LOG callbacks_initial.err BIN callbacks.sav @frama-c@ @PTEST_DIR@/callbacks.i -out -calldeps -eva-show-progress -main main1 -save @PTEST_RESULT@/callbacks.sav > @PTEST_RESULT@/callbacks_initial.res 2> @PTEST_RESULT@/callbacks_initial.err
   STDOPT: +"-load @PTEST_RESULT@/callbacks.sav -main main2 -then -main main3"
*/

/* This tests whether the callbacks for callwise inout and from survive after
   a saveload or a -then */

void f(int *p) {
  *p = 1;
}

int x, y;

void g1() {
  f(&x);
}


void g2() {
  f(&y);
}

void main1() {
  g1();
  g2();
}

void main2() {
  g1();
  g2();
}

void main3() {
  g1();
  g2();
}
