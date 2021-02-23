/* run.config_ci
  COMMENT: frama-c/e-acsl#145, test for validity of globals_init and
  globals_clean.
  STDOPT: +"-verbose 1 -eva-print"
*/
int G = 0;

int main(void) {
  /*@ assert \valid(&G); */
  int a = G;
  return 0;
}
