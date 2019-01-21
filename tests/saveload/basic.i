/* run.config
   EXECNOW: make -s ./@PTEST_DIR@/@PTEST_NAME@.cmxs
   EXECNOW: LOG basic_sav.res LOG basic_sav.err BIN basic.sav @frama-c@ -load-module ./@PTEST_DIR@/@PTEST_NAME@ -eva -out -input -deps -eva-show-progress ./tests/saveload/basic.i -save ./tests/saveload/result/basic.sav > ./tests/saveload/result/basic_sav.res 2> ./tests/saveload/result/basic_sav.err
   EXECNOW: LOG basic_sav.1.res LOG basic_sav.1.err BIN basic.1.sav ./bin/toplevel.opt -save ./tests/saveload/result/basic.1.sav ./@PTEST_DIR@/@PTEST_NAME@.i -eva -out -input -deps -eva-show-progress > ./tests/saveload/result/basic_sav.1.res 2> ./tests/saveload/result/basic_sav.1.err
   OPT: -load ./tests/saveload/result/basic.sav -eva -out -input -deps -journal-disable
   CMD: @frama-c@ -load-module ./@PTEST_DIR@/@PTEST_NAME@
   OPT: -load ./tests/saveload/result/basic.1.sav -eva -out -input -deps -journal-disable -print
   OPT: -load ./tests/saveload/result/basic.1.sav -eva -out -input -deps -journal-disable
   EXECNOW: LOG status_sav.res LOG status_sav.err BIN status.sav @frama-c@ -load-script tests/saveload/status.ml -save ./tests/saveload/result/status.sav ./@PTEST_DIR@/@PTEST_NAME@.i > ./tests/saveload/result/status_sav.res 2> ./tests/saveload/result/status_sav.err
   OPT: -load-script tests/saveload/status.ml -load ./tests/saveload/result/status.sav
   OPT: -load ./tests/saveload/result/status.sav
*/

int main() {
  int i, j;

  i = 10;
  /*@ assert (i == 10); */
  while(i--);
  j = 5;

  return 0;
}
