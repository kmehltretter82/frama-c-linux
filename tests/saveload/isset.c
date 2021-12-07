/* run.config
   EXECNOW: LOG isset_sav.res LOG isset_sav.err BIN isset.sav @frama-c@ -quiet -eva @EVA_OPTIONS@ -save @PTEST_RESULT@/isset.sav %{dep:@PTEST_DIR@/isset.c} > @PTEST_RESULT@/isset_sav.res 2> @PTEST_RESULT@/isset_sav.err
   STDOPT: +"-quiet -load @PTEST_RESULT@/isset.sav"
   STDOPT: +"-load @PTEST_RESULT@/isset.sav"
   STDOPT: +"-eva @EVA_OPTIONS@ -load @PTEST_RESULT@/isset.sav"
   STDOPT: +"-quiet -eva @EVA_OPTIONS@ -load @PTEST_RESULT@/isset.sav"
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
