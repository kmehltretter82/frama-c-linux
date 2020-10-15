/* run.config
   MODULE: @PTEST_NAME@.cmxs
   OPT: -eva @EVA_OPTIONS@ -eva-slevel-function main:10
*/
void main() {
  int i, j = 0;
  for (i=0; i<10; i++) {
    j++;
  }
  //@ assert i == j;
}
