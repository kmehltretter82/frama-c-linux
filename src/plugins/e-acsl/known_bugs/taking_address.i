int main(){
  int m, *u, *p;
  u = &m;
  p = u;
  m = 123;
  //@ assert \initialized(p);
}
