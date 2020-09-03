/* run.config
   EXECNOW: LOG isset_sav.res LOG isset_sav.err BIN isset.sav ./bin/toplevel.opt -quiet -eva @EVA_OPTIONS@ -save result/isset.sav isset.c > ./result/isset_sav.res 2> ./result/isset_sav.err
   STDOPT: +"-quiet -load ./result/isset.sav"
   STDOPT: +"-load ./result/isset.sav"
   STDOPT: +"-eva @EVA_OPTIONS@ -load ./result/isset.sav"
   STDOPT: +"-quiet -eva @EVA_OPTIONS@ -load ./result/isset.sav"
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
