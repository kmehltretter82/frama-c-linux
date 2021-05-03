/* run.config
   CMXS: segfault_datatypes_A segfault_datatypes_B
   EXECNOW: LOG segfault_datatypes_sav.res LOG segfault_datatypes_sav.err BIN segfault_datatypes.sav @frama-c@ -load-module %{dep:segfault_datatypes_A.cmxs} -eva @EVA_OPTIONS@ -out -input -deps -save segfault_datatypes.sav > segfault_datatypes_sav.res 2> segfault_datatypes_sav.err
   CMD: @frama-c@ -load-module %{dep:segfault_datatypes_B.cmxs} @PTEST_OPTIONS@
   STDOPT: +"-load %{dep:segfault_datatypes.sav} -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
*/


int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
