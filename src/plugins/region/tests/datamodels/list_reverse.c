#include <stddef.h>

typedef struct Cell {
  int value;
  struct Cell *next;
} list;

/*@
  ensures \result == \null;
  produces Q: { List \with .head = q };
*/
list *newcell(void);

/*@
datamodel List {
  pmodel (list *) head;
  pmodel (\list<integer>) values;
  pcase Nil {
    pwhen head == \null;
    pinvariant values == \Nil;
  }
  pcase Cons {
    pwhen head != \null;
    pframe *head ;
    pframe Tail: { List \with .head = head->next };
    pinvariant
      values == \Cons( head->value, Tail.values );
  }
}
*/

/*@
  requires p != \null;
  requires \valid(p);
  consumes P: { List \with .head = p };
  produces Q: { List \with .head = q };
*/
list *reverse(list *p) {

  list *q = newcell();
  //@ produce Q: { List::Nil \with .head=q, .values = \Nil };

  /*@
    loop frame P: { List \with .head = p };
    loop frame Q: { List \with .head = q };
    loop assigns p, q;
  */
  while (!p){
    //@ consume P: { List::Cons \with .Tail=P };
    list *tmp = p->next;
    p->next = q;
    q = p;
    p = tmp;
    /*@ produce Q: { List::Cons \with
      .head=q, .Tail=Q,
      .values=\Cons(q->values,Q.values)
    }; */
  }
  //@ consume P: { List::Nil };
  return q;
}
