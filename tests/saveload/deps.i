/* run.config
   CMXS: deps_A deps_B deps_C deps_D deps_E
   EXECNOW: LOG deps_sav.res LOG deps_sav.err BIN deps.sav @frama-c@ -load-module %{dep:deps_A.cmxs} -eva @EVA_OPTIONS@ -out -input -deps ./deps.i -save deps.sav > ./result/deps_sav.res 2> ./result/deps_sav.err
   STDOPT: +"-load-module %{deps:deps_A} -load ./result/deps.sav -eva @EVA_OPTIONS@ -out -input -deps "
   STDOPT: +"-load-module %{deps:deps_B} -load ./result/deps.sav  -out -input -deps "
   STDOPT: +"-load-module %{deps:deps_C} -load ./result/deps.sav  -out -input -deps "
   STDOPT: +"-load-module %{deps:deps_D} -load ./result/deps.sav  -out -input -deps "
   STDOPT: +"-load-module %{deps:deps_E} -load ./result/deps.sav  -out -input -deps "
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
