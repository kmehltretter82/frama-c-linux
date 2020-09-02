/* run.config
   CMXS: @PTEST_NAME@
   OPT: -eva @EVA_CONFIG@ -slevel-function main:10 -load-module %{dep:@PTEST_NAME@.cmxs}
*/
void main() {
  int i, j = 0;
  for (i=0; i<10; i++) {
    j++;
  }
  //@ assert i == j;
}
