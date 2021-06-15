/* run.config
 MODULE: deps_A
   EXECNOW: LOG deps_sav.res LOG deps_sav.err BIN deps.sav @frama-c@ -eva @EVA_OPTIONS@ -out -input -deps @PTEST_FILE@ -save ./tests/saveload/result/deps.sav > ./tests/saveload/result/deps_sav.res 2> ./tests/saveload/result/deps_sav.err
   STDOPT: +"-load ./tests/saveload/result/deps.sav -eva @EVA_OPTIONS@ -out -input -deps "
 MODULE: deps_B
   STDOPT: +"-load ./tests/saveload/result/deps.sav  -out -input -deps "
 MODULE: deps_C
   STDOPT: +"-load ./tests/saveload/result/deps.sav  -out -input -deps "
 MODULE: deps_D
   STDOPT: +"-load ./tests/saveload/result/deps.sav  -out -input -deps "
 MODULE: deps_E
   STDOPT: +"-load ./tests/saveload/result/deps.sav  -out -input -deps "
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
