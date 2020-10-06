/* run.config
   EXECNOW: LOG isset_sav.res LOG isset_sav.err BIN isset.sav ./bin/toplevel.opt -quiet -eva @EVA_OPTIONS@ -save isset.sav isset.c > isset_sav.res 2> isset_sav.err
   STDOPT: +"-quiet -load isset.sav"
   STDOPT: +"-load isset.sav"
   STDOPT: +"-eva @EVA_OPTIONS@ -load isset.sav"
   STDOPT: +"-quiet -eva @EVA_OPTIONS@ -load isset.sav"
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
