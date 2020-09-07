/*@ check lemma tauto: \true ==> \true; */

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
