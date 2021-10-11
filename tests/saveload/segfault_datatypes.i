/* run.config
 MODULE: segfault_datatypes_A
   EXECNOW: LOG segfault_datatypes_sav.res LOG segfault_datatypes_sav.err BIN segfault_datatypes.sav @frama-c@ -eva @EVA_OPTIONS@ -out -input -deps -save segfault_datatypes.sav > segfault_datatypes_sav.res 2> segfault_datatypes_sav.err
 MODULE: segfault_datatypes_B
   STDOPT: +"-load %{dep:segfault_datatypes.sav} -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
*/


int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
