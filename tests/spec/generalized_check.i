/* run.config
OPT: -wp-fct f,main -wp -wp-prover qed -wp-msg-key strategy,no-time-info -print
*/
/*@ check lemma easy_proof: \false; */ // should not be put in any environment

/*@ check requires \valid(x);
    assigns *x;
    check ensures *x == 0;
*/
void f(int* x) {
  /*@ check \valid(x); */ // can't be proved by WP: we ignore the requires
  *x = 0;
}

int main() {
  int a = 4;
  f(&a);
  /*@ check a == 0; */ // can't be proved by WP: we ignore the ensures
}

void loop () {
  /*@ check loop invariant \true; */
  for (int i = 0; i< 10; i++);
  int j = 0;
 l: /*@ check invariant \true; */ ;
  if (j >= 10) goto l1;
  j++;
  goto l;
 l1 : ;
}
