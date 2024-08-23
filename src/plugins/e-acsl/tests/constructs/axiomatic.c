/* run.config
COMMENT: [e-acsl] Failure: typing was not performed on construct s in phase `analysis:typing'
*/

/*@
  axiomatic p {
    predicate p(ℤ s);
  }
*/

/*@ ensures p(s); */
void f(int s) {
  return;
}

int main() {
  f(2);
}
