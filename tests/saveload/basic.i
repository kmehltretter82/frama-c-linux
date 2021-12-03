/* run.config
 MODULE: @PTEST_NAME@
   EXECNOW: LOG basic_sav.res LOG basic_sav.err BIN basic.sav @frama-c@ -eva @EVA_OPTIONS@ -out -input -deps @PTEST_FILE@ -save @PTEST_RESULT@/basic.sav > @PTEST_RESULT@/basic_sav.res 2> @PTEST_RESULT@/basic_sav.err
 MODULE:
   EXECNOW: LOG basic_sav.1.res LOG basic_sav.1.err BIN basic.1.sav @frama-c@ -save @PTEST_RESULT@/basic.1.sav @PTEST_FILE@ -eva @EVA_OPTIONS@ -out -input -deps > @PTEST_RESULT@/basic_sav.1.res 2> @PTEST_RESULT@/basic_sav.1.err
   STDOPT: +"-load @PTEST_RESULT@/basic.sav -eva @EVA_OPTIONS@ -out -input -deps"
 MODULE: @PTEST_NAME@
   STDOPT: +"-load @PTEST_RESULT@/basic.1.sav -eva @EVA_OPTIONS@ -out -input -deps -print"
 MODULE:
   STDOPT: +"-load @PTEST_RESULT@/basic.1.sav -eva @EVA_OPTIONS@ -out -input -deps"
 MODULE: status
   EXECNOW: LOG status_sav.res LOG status_sav.err BIN status.sav @frama-c@ -save @PTEST_RESULT@/status.sav @PTEST_FILE@ > @PTEST_RESULT@/status_sav.res 2> @PTEST_RESULT@/status_sav.err
   STDOPT: +"-load @PTEST_RESULT@/status.sav"
 MODULE:
   STDOPT: +"-load @PTEST_RESULT@/status.sav"
*/
int main() {
  int i,j; i=10; /*@ assert (i == 10); */
  while(i--);
  j = 5;

  return 0;
}
