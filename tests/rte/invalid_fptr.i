/* run.config
OPT: -rte -warn-invalid-pointer -print
*/

struct S { void (*f)(void); } s;

void (*p)(void);

void f(void) {
  if (p) return; // should not warn
  if (p+2) return; // should warn
  if (s.f) return; //should not warn
  if (s.f+2) return; // should warn
  return;
}
