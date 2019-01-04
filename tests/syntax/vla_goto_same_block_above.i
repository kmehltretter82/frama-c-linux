volatile int nondet ;
int main() {
  int i = 42 ;
  toto : ;
  char vla[i] ;
  if (nondet) goto toto ;
  return 0 ;
}
