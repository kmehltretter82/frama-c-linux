struct S;

extern struct S S1;
extern struct S S2;

/*@ axiomatic test{
  @ check lemma should_fail : S1 == S2;
  @ check lemma should_succeed : S1 == S1;
}*/

/*@ assigns S1; */
void f(void);

void assigns(void){
  f();
  /*@ check should_fail: S1 == \at(S1,Pre);*/
  /*@ check should_succeed: S2 == \at(S2,Pre);*/
}

struct S* p ;

//@ assigns *p ;
void g(void);

/*@ requires \initialized(p); */
void initialized_assigns(void){
  g();
  //@ check should_succeed: \initialized(p);
}

/*@ requires ! \initialized(p); */
void uninitialized_assigns(void){
  g();
  /* NOTE:
     both shoud FAIL as we cannot prove that:
     - it is still uninitialized,
     - it has been initialized.
  */
  //@ check should_fail: ! \initialized(p);
  //@ check should_fail:   \initialized(p);
}
