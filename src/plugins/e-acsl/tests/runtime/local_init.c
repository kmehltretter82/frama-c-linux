/* run.config
   COMMENT: test of a local initializer which contains an annotation
   STDOPT: #"-val -value-verbose 0 -lib-entry -e-acsl-prepare -machdep gcc_x86_64 -then"
*/

int X = 0;
int *p = &X;

int f(void) {
  int x = *p; // Eva add an alarms on this statement
  return x;
}

int main(void) {
  f();
  return 0;
}
