/* run.config
 MODULE: @PTEST_NAME@
   EXECNOW: LOG basic_sav.res LOG basic_sav.err BIN basic.sav @frama-c@ -load-module @PTEST_DIR@/@PTEST_NAME@.cmxs -eva @EVA_OPTIONS@ -out -input -deps ./@PTEST_DIR@/@PTEST_NAME@.i -save ./tests/saveload/result/basic.sav > ./tests/saveload/result/basic_sav.res 2> ./tests/saveload/result/basic_sav.err
   EXECNOW: LOG basic_sav.1.res LOG basic_sav.1.err BIN basic.1.sav @frama-c@ -save ./tests/saveload/result/basic.1.sav @PTEST_DIR@/@PTEST_NAME@.i -eva @EVA_OPTIONS@ -out -input -deps > ./tests/saveload/result/basic_sav.1.res 2> ./tests/saveload/result/basic_sav.1.err
 MODULE:
   STDOPT: +"-load ./tests/saveload/result/basic.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
 MODULE: @PTEST_NAME@
   STDOPT: +"-load ./tests/saveload/result/basic.1.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable -print"
 MODULE:
   STDOPT: +"-load ./tests/saveload/result/basic.1.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
 MODULE: status
   EXECNOW: LOG status_sav.res LOG status_sav.err BIN status.sav @frama-c@ -load-module @PTEST_DIR@/status -save ./tests/saveload/result/status.sav @PTEST_DIR@/@PTEST_NAME@.i > ./tests/saveload/result/status_sav.res 2> ./tests/saveload/result/status_sav.err
   STDOPT: +"-load ./tests/saveload/result/status.sav"
 MODULE:
   STDOPT: +"-load ./tests/saveload/result/status.sav"
*/
int main() {
  int i,j; i=10; /*@ assert (i == 10); */
  while(i--);
  j = 5;

  return 0;
}
