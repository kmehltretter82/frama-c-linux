
/*@
datamodel Test {
  pmodel (int) i;
  pmodel (\list<integer>) ls;
  pframe F1: { Test \with .i = 0, .ls = \Nil };
  pinvariant i >= 0;
  pcase C1 {
    pwhen i == 2;
    pinvariant ls == \Nil;
  }
  pcase C2 {
    pinvariant i == 0;
    pframe *f;
    pframe F: { Test \with .i = 0, .ls = \Nil };
  }
}
*/

/*@ 
    requires \true;
    consumes P: { Test \with .i = 0, .ls = \Nil };
    produces Q: { Test \with .i = 0, .ls = \Nil };
*/
void foo(void) {
  //@ assert \true;

  /*@
    loop frame Q: { Test \with .i = 0, .ls = \Nil };
    loop invariant \true;
  */
  while (1)
      break;

  //@ call { foo \with .P = --A, .Q = ++B };
  int x= 0;  
  //@ frame Tail: { List \with .head = head->next };
  //@ heap p;

  x++;

  //@ consume P: { Test::C2 \with .i = 0, .ls = \Nil };
  //@ produce Q: { Test::C1 \with .i = 2, .ls = \Nil };
  return ;
}
