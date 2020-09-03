/* run.config
   CMXS: segfault_datatypes_A segfault_datatypes_B
   EXECNOW: LOG segfault_datatypes_sav.res LOG segfault_datatypes_sav.err BIN segfault_datatypes.sav @frama-c@ -load-module ./segfault_datatypes_A -eva @EVA_OPTIONS@ -out -input -deps ./segfault_datatypes.i -save ./result/segfault_datatypes.sav > ./result/segfault_datatypes_sav.res 2> ./result/segfault_datatypes_sav.err
   CMD: @frama-c@ -load-module ./segfault_datatypes_B
   STDOPT: +"-load ./result/segfault_datatypes.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
*/


int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
