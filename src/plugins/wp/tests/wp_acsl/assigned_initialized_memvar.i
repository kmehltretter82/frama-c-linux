struct S {
  int i ;
  int a[10] ;
};

int main(void){
  struct S s ;
  s.i = 0 ;
  /*@
    loop invariant 0 <= i <= 10;
    loop invariant \initialized(&s.a[0 .. i-1]);
    loop assigns i, s.a[0 .. 9];
  */
  for(int i = 0; i < 10; ++i) s.a[i] = 0;

  //@ check \initialized(&s);

  /*@ loop assigns i, s.a[1 .. 4]; */
  for(int i = 0; i < 10; ++i){
    if(1 <= i && i <= 4) s.a[i] = 1 ;
  }

  //@ check \initialized(&s);
  
  /*@ loop assigns i, s.i; */
  for(int i = 0; i < 10; ++i){
    s.i++;
  }

  //@ check \initialized(&s);
  
  /*@ 
    loop invariant 0 <= i <= 10;
    loop assigns i, s.a[0..9]; 
  */
  for(int i = 0; i < 10; ++i){
    s.a[i] = 1 ;
  }

  //@ check \initialized(&s);

  /*@ loop assigns i, s.a[4]; */
  for(int i = 0; i < 10; ++i){
    if(i == 4) s.a[i] = 1 ;
  }

  //@ check \initialized(&s);

  /*@ loop assigns i, { s.a[i] | integer i ; i \in { 0, 2, 4 } }; */
  for(int i = 0; i < 10; ++i){
    if(i == 0 || i == 2 || i == 4) s.a[i] = 1 ;
  }
  
  //@ check \initialized(&s);
  //@ check SMOKE: \false;
}

