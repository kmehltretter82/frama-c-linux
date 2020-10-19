/* run.config
   PLUGIN: @PLUGIN@ report from,inout,eva,scope,variadic
   OPT: -eva -then -report
   OPT: -wp-prop=@check
   OPT: -wp-prop=-@check
*/
/* run.config_qualif
   PLUGIN: @PLUGIN@ report
   OPT: -wp-steps 5 -then -report
*/
// note: eva and wp gives the same reporting
//@ axiomatic A { predicate P reads \nothing ; }
void main() {
  //@check  c1: P;
  //@assert a1: P;
  //@check  c2: P;
  //@assert a2: P;
  ;
}
