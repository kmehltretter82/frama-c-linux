/* run.config
   COMMENT: addrOf
   COMMENT: no diff
   COMMENT: no diff
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
