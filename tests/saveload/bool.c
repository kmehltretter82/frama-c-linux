/* run.config
<<<<<<< HEAD
   EXECNOW: BIN bool.sav LOG bool_sav.res LOG bool_sav.err @frama-c@ -save bool.sav -machdep x86_32 -eva @EVA_OPTIONS@ > bool_sav.res 2> bool_sav.err
   STDOPT: +"-load %{dep:bool.sav} -out -input -deps"
   STDOPT: +"-load %{dep:bool.sav} -eva @EVA_OPTIONS@"
||||||| ac7807782d
   EXECNOW: BIN bool.sav LOG bool_sav.res LOG bool_sav.err ./bin/toplevel.opt -save ./tests/saveload/result/bool.sav -eva @EVA_OPTIONS@ ./tests/saveload/bool.c > tests/saveload/result/bool_sav.res 2> tests/saveload/result/bool_sav.err
   STDOPT: +"-load ./tests/saveload/result/bool.sav -out -input -deps"
   STDOPT: +"-load ./tests/saveload/result/bool.sav -eva @EVA_OPTIONS@"
=======
   EXECNOW: BIN bool.sav LOG bool_sav.res LOG bool_sav.err ./bin/toplevel.opt -save ./tests/saveload/result/bool.sav -machdep x86_32 -eva @EVA_OPTIONS@ ./tests/saveload/bool.c > tests/saveload/result/bool_sav.res 2> tests/saveload/result/bool_sav.err
   STDOPT: +"-load ./tests/saveload/result/bool.sav -out -input -deps"
   STDOPT: +"-load ./tests/saveload/result/bool.sav -eva @EVA_OPTIONS@"
>>>>>>> origin/master
 */

#include "stdbool.h"
#include "stdio.h"

bool x;
int y;

int f() {
  int i, j;

  i = 10;
  /*@ assert (i == 10); */
  while(i--);
  j = 5;

  return 0;
}

int main() {
  f();
  x=false;
  printf("%d\n",x);
  x=2;
  printf("%d\n",x);
  y=x+1;
  printf("%d,%d\n",x,y);
  x=x+1;
  printf("%d\n",x);
  x=x+1;
  printf("%d\n",x);
  return y;
}
