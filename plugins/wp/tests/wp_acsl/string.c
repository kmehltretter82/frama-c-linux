/* run.config
  OPT: -wp-no-qed -wp-prop A,Z
  OPT: -wp-no-qed -wp-prop A,Z -wp-literals
*/

/* run.config_qualif
  DONTRUN:
*/

// String Literals

char a[8] = "Abc";

//@ assigns \result \from \nothing;
int main(void) {
  //@ check A: a[0] == 'A' ;
  //@ check Z: a[sizeof("Abc")-1] == '\0' ;
  return 0;
}
