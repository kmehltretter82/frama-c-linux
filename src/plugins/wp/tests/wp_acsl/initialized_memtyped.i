struct S {
  int x ;
  int y ;
} ;
struct C {
  int x ;
  struct S s ;
  int a[10] ;
} ;

void test(int* x, int (*a)[2], struct C* c){
  //@ check unknown: \initialized(x);
  //@ check unknown: \initialized(a);
  //@ check unknown: \initialized(c);

  *x = 1 ;
  //@ check qed_ok: \initialized(x);

  (*a)[0] = 1 ;
  //@ check qed_ok: \initialized(&(*a)[0]);
  //@ check unknown: \initialized(&(*a)[1]);
  //@ check unknown: \initialized(&(*a));

  (*a)[1] = 2 ;
  //@ check qed_ok: \initialized(&(*a)[0]);
  //@ check qed_ok: \initialized(&(*a)[1]);
  //@ check qed_ok: \initialized(&a);

  c->x = 1 ;
  //@ check qed_ok: \initialized(&c->x);
  //@ check unknown: \initialized(&c->s);
  //@ check unknown: \initialized(&c->a);
  //@ check unknown: \initialized(c);

  c->s.x = 1;
  //@ check qed_ok: \initialized(&c->s.x);
  //@ check unknown: \initialized(&c->s.y);
  //@ check unknown: \initialized(&c->s);
  //@ check unknown: \initialized(c);

  c->s.y = 1 ;
  //@ check qed_ok: \initialized(&c->s);
  //@ check unknown: \initialized(c);

  c->a[0] = c->a[1] = c->a[2] = c->a[3] = c->a[4] = c->a[5] = c->a[6] = c->a[7] = c->a[8] = 1;
  //@ check provable: \initialized(&c->a[0..8]) ;
  //@ check unknown: \initialized(c);

  c->a[9] = 1 ;
  //@ check qed_ok: \initialized(c);
}
