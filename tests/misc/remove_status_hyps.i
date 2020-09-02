/* run.config
   CMXS: @PTEST_NAME@
   OPT: -no-autoload-plugins -load-module %{dep:@PTEST_NAME@.cmxs}
*/

int main(void) {
  /*@ assert P1: \true; */;
  /*@ assert P2: \true; */;
  /*@ assert P3: \true; */;
  /*@ assert P4: \true; */;
  return 0;
}
