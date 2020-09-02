/* run.config
   CMXS: @PTEST_NAME@
   OPT: -load-module %{dep:@PTEST_NAME@.cmxs}
*/
//@ ensures *p==1;
void main(int * p){ *p = 0; }
