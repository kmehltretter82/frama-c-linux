/* run.config
 MODULE: deps_A
   EXECNOW: LOG deps_sav.res LOG deps_sav.err BIN deps.sav @frama-c@ -eva @EVA_OPTIONS@ -out -input -deps @PTEST_FILE@ -save @PTEST_RESULT@/deps.sav > @PTEST_RESULT@/deps_sav.res 2> @PTEST_RESULT@/deps_sav.err
   STDOPT: +"-load %{dep:@PTEST_RESULT@/deps.sav} -eva @EVA_OPTIONS@ -out -input -deps "
 MODULE: deps_B
   STDOPT: +"-load %{dep:@PTEST_RESULT@/deps.sav}  -out -input -deps "
 MODULE: deps_C
   STDOPT: +"-load %{dep:@PTEST_RESULT@/deps.sav}  -out -input -deps "
 MODULE: deps_D
   STDOPT: +"-load %{dep:@PTEST_RESULT@/deps.sav}  -out -input -deps "
 MODULE: deps_E
   STDOPT: +"-load %{dep:@PTEST_RESULT@/deps.sav}  -out -input -deps "
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
