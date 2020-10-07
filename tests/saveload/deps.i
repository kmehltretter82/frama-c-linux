/* run.config
   CMXS: deps_A deps_B deps_C deps_D deps_E
   EXECNOW: LOG deps_sav.res LOG deps_sav.err BIN @PTEST_NAME@.sav @frama-c@ -load-module %{dep:deps_A.cmxs} -eva @EVA_OPTIONS@ -out -input -deps -save @PTEST_NAME@.sav > deps_sav.res 2> deps_sav.err
   STDOPT: +"-load-module %{dep:deps_A.cmxs} -load %{dep:@PTEST_NAME@.sav} -eva @EVA_OPTIONS@ -out -input -deps "
   STDOPT: +"-load-module %{dep:deps_B.cmxs} -load %{dep:@PTEST_NAME@.sav}  -out -input -deps "
   STDOPT: +"-load-module %{dep:deps_C.cmxs} -load %{dep:@PTEST_NAME@.sav}  -out -input -deps "
   STDOPT: +"-load-module %{dep:deps_D.cmxs} -load %{dep:@PTEST_NAME@.sav}  -out -input -deps "
   STDOPT: +"-load-module %{dep:deps_E.cmxs} -load %{dep:@PTEST_NAME@.sav}  -out -input -deps "
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
