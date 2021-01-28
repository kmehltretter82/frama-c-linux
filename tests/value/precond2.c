/* run.config*
<<<<<<< HEAD
   PLUGIN: @PLUGIN@ report
   OPT: -machdep x86_32 -rte -then -eva @EVA_OPTIONS@ -then -report -report-print-properties
   OPT: -machdep x86_32 -eva @EVA_OPTIONS@ -then -rte -then -report -report-print-properties
||||||| ac7807782d
   OPT: -no-autoload-plugins -load-module from,inout,eva,report,rtegen -rte -then -eva @EVA_CONFIG@ -then -report -report-print-properties
   OPT: -no-autoload-plugins -load-module from,inout,eva,report,rtegen -eva @EVA_CONFIG@ -then -rte -then -report -report-print-properties
=======
   OPT: -machdep x86_32 -no-autoload-plugins -load-module from,inout,eva,report,rtegen -rte -then -eva @EVA_CONFIG@ -then -report -report-print-properties
   OPT: -machdep x86_32 -no-autoload-plugins -load-module from,inout,eva,report,rtegen -eva @EVA_CONFIG@ -then -rte -then -report -report-print-properties
>>>>>>> origin/master
*/
// Fuse with precond.c when bts #1208 is solved
int x;

/*@ requires i_plus_one: i+1 >= 0;
  requires i: i >= 0;
  assigns x; */
void f (int i) {
  x = i;
}

//@ requires x <= 8;
void g(void);

void main (int c) {
  if (c) {
    f(1);
    if(c) f(-1);
  }
  g ();g ();
}
