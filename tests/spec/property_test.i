/* run.config
   CMXS: @PTEST_NAME@
   OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
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
