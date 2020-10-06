/* run.config
   EXECNOW: LOG @PTEST_NAME@_initial.res LOG @PTEST_NAME@_initial.err BIN @PTEST_NAME@.sav @frama-c@ @PTEST_NAME@.i -out -calldeps -eva-show-progress -main main1 -save @PTEST_NAME@.sav > @PTEST_NAME@_initial.res 2> @PTEST_NAME@_initial.err
   STDOPT: +"-load %{dep:@PTEST_NAME@.sav} -main main2 -then -main main3"
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
