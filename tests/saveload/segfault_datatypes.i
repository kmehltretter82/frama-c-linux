/* run.config*


 MODULE: segfault_datatypes_A
   EXECNOW: BIN @PTEST_NAME@.sav LOG @PTEST_NAME@_sav.res LOG @PTEST_NAME@_sav.err @frama-c@ -eva @EVA_OPTIONS@ -out -input -deps @PTEST_FILE@ -save @PTEST_NAME@.sav > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
 MODULE: segfault_datatypes_B
   STDOPT: +"-load %{dep:@PTEST_NAME@.sav} -eva -out -input -deps"
*/

int main() {
  int i, j;

  i = 10;
  while(i--);
  j = 5;

  return 0;
}
