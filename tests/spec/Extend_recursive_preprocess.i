/* run.config
MODULE: @PTEST_DIR@/@PTEST_NAME@.cmxs
OPT: -no-autoload-plugins -kernel-warn-key=annot-error=active -print
*/

/*@ bhv_foo must_replace(x); */
int f(int x);

/*@ behavior test:
  bhv_foo must_replace(x);
*/
int g(int x);


int f(int x) {
  int s = 0;
  /*@ loop nl_foo must_replace(x); */
  for (int i = 0; i < x; i++) s+=g(i);
  /*@ ca_foo must_replace(x); */
  return s;
}

int k(int z) {
  int x = z;
  int y = 0;
  /*@ ns_foo must_replace(x); */
  y = x++;
  return y;
}

/*@ gl_foo must_replace(x); */


/*@ gl_foo foo1 {
    gl_fooo must_replace(x);
    gl_foo foo2 {
      gl_fooo must_replace(x);
      gl_foo foo3 {
         gl_fooo must_replace(x);
         gl_fooo must_replace(x);
      };
      gl_fooo must_replace(x);
    };
    gl_fooo must_replace(x);
}*/

//frama-c -no-autoload-plugins -kernel-warn-key=annot-error=active -print -load-script Extend_recursive_preprocess.ml Extend_recursive_preprocess.i
