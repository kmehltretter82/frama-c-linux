/* run.config
   MODULE: @PTEST_NAME@.cmxs
   OPT:
*/

int X;

/*@ requires X >= 0;
    ensures X >= 0;
*/
int main (int c) {
  if (c) X++;
  /*@ assert X >= \at(X,Pre); */
  return X;
}
