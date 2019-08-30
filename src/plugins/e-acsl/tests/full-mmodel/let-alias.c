/* run.config_dev
   DONTRUN:
*/

/* let binding on alias, memory must be fully instrumented */

int main(void) {
  int t[4] = {1,2,3,4};
  /*@ assert \let u = t + 1; *(u + 2) == 4; */ ;
  /*@ assert (\let u = t + 1; *(u + 2)) == 4; */ ;
  return 0;
}
