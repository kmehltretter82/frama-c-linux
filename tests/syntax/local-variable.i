int main(){
  {
    int a ;
  }
  ; // < NOP inserted
}

void f() {
  if (0) {
    int b;
  }
}

int c;
int g() { return 1 || (-1L || g(), c); }
