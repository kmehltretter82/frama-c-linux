/* run.config
 MODULE: deps_A
   EXECNOW: LOG deps_sav.res LOG deps_sav.err BIN @PTEST_NAME@.sav @frama-c@ -eva @EVA_OPTIONS@ -out -input -deps -save @PTEST_NAME@.sav > deps_sav.res 2> deps_sav.err
   STDOPT: +"-load %{dep:@PTEST_NAME@.sav} -eva @EVA_OPTIONS@ -out -input -deps "
 MODULE: deps_B
   STDOPT: +"-load %{dep:@PTEST_NAME@.sav}  -out -input -deps "
 MODULE: deps_C
   STDOPT: +-load %{dep:@PTEST_NAME@.sav}  -out -input -deps "
 MODULE: deps_D
   STDOPT: +"-load %{dep:@PTEST_NAME@.sav}  -out -input -deps "
 MODULE: deps_E
   STDOPT: +"-load %{dep:@PTEST_NAME@.sav}  -out -input -deps "
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
