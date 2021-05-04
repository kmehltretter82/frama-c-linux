/* run.config*
 MODULE: segfault_datatypes_A
   EXECNOW: LOG segfault_datatypes_sav.res LOG segfault_datatypes_sav.err BIN segfault_datatypes.sav @frama-c@ -eva @EVA_OPTIONS@ -out -input -deps @PTEST_FILE@ -save ./tests/saveload/result/segfault_datatypes.sav > ./tests/saveload/result/segfault_datatypes_sav.res 2> ./tests/saveload/result/segfault_datatypes_sav.err
 MODULE: segfault_datatypes_B
   STDOPT: +"-load ./tests/saveload/result/segfault_datatypes.sav -eva -out -input -deps"
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
