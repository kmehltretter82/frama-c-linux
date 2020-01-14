/* run.config_dev
   COMMENT: issue with function pointers on CI
   DONTRUN:
*/
/* run.config_ci
   COMMENT: addrOf
*/

void f(){
  int m, *u, *p;
  u = &m;
  p = u;
  m = 123;
  //@ assert \initialized(p);
}

int main(void) {
  int x = 0;
  f();
  /*@ assert &x == &x; */ ;
  return 0;
}
