/* run.config
   NOFRAMAC: testing frama-c-script, not frama-c itself
   EXECNOW: LOG recursions.res LOG recursions.err bin/frama-c-script heuristic-detect-recursion @PTEST_FILE@ > @PTEST_DIR@/result/recursions.res 2> @PTEST_DIR@/result/recursions.err
*/

volatile int v;

void g() {
  int g = 42;
}

void f() {
  if (v) f();
  else g();
}

void h() {
  if (v) h();
  else g();
}

void i() {
  g();
}

void j() {
  f();
}

void l(void);
void m(void);

void k() {
  if (v) l();
}

void l() {
  if (v) m();
}

void m() {
  if (v) k();
}

void norec() {
}
