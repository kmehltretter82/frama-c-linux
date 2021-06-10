/* run.config
 MODULE: @PTEST_NAME@
   EXECNOW: LOG basic_sav.res LOG basic_sav.err BIN basic.sav @frama-c@ -eva @EVA_OPTIONS@ -out -input -deps @PTEST_FILE@ -save ./tests/saveload/result/basic.sav > ./tests/saveload/result/basic_sav.res 2> ./tests/saveload/result/basic_sav.err
 MODULE:
   EXECNOW: LOG basic_sav.1.res LOG basic_sav.1.err BIN basic.1.sav @frama-c@ -save ./tests/saveload/result/basic.1.sav @PTEST_FILE@ -eva @EVA_OPTIONS@ -out -input -deps > ./tests/saveload/result/basic_sav.1.res 2> ./tests/saveload/result/basic_sav.1.err
   STDOPT: +"-load ./tests/saveload/result/basic.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
 MODULE: @PTEST_NAME@
   STDOPT: +"-load ./tests/saveload/result/basic.1.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable -print"
 MODULE:
   STDOPT: +"-load ./tests/saveload/result/basic.1.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
 MODULE: status
   EXECNOW: LOG status_sav.res LOG status_sav.err BIN status.sav @frama-c@ -save ./tests/saveload/result/status.sav @PTEST_FILE@ > ./tests/saveload/result/status_sav.res 2> ./tests/saveload/result/status_sav.err
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
