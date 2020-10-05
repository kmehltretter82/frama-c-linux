/* run.config
   CMXS: one_hyp several_hyps
   OPT: -load-module %{dep:one_hyp.cmxs}
   OPT: -load-module %{dep:several_hyps.cmxs}
*/
void f(void);
void f2(void);
void g() {
  /*@ assert \true; */
}

void h() {
  /*@ assert \false; */
}

void i() {
  /*@ assert 1 == 2; */
}

void j() {
  /*@ assert 2 == 3; */
}

void main() {
  /*@ assert 0 == 1; */
  f();
  f2();
  g();
  h();
  i();
  j();
}
