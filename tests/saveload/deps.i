/* run.config
   CMXS: deps_A deps_B deps_C deps_D deps_E
   EXECNOW: LOG deps_sav.res LOG deps_sav.err BIN deps.sav @frama-c@ -load-module %{dep:deps_A.cmxs} -eva @EVA_OPTIONS@ -out -input -deps ./deps.i -save deps.sav > deps_sav.res 2> deps_sav.err
   STDOPT: +"-load-module %{dep:deps_A.cmxs} -load %{dep:deps.sav} -eva @EVA_OPTIONS@ -out -input -deps "
   STDOPT: +"-load-module %{dep:deps_B.cmxs} -load %{dep:deps.sav}  -out -input -deps "
   STDOPT: +"-load-module %{dep:deps_C.cmxs} -load %{dep:deps.sav}  -out -input -deps "
   STDOPT: +"-load-module %{dep:deps_D.cmxs} -load %{dep:deps.sav}  -out -input -deps "
   STDOPT: +"-load-module %{dep:deps_E.cmxs} -load %{dep:deps.sav}  -out -input -deps "
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
