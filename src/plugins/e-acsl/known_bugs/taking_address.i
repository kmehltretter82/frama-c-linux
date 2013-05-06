int main(){
  int m,*u,**p;
  u=&m;
  m=123;
  p=&u;
  //@ assert \initialized(u);
}
