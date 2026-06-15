
typedef struct Cell {
  int value;
  struct Cell *next;
} list;

/*@
datamodel List {
  model list *head;
  model \list<integer> values;
  case Nil {
    when head == \null;
    invariant values == \Nil;
  }
  case Cons {
    when head != \null;
    frame *head ;
    frame { Tail: List with head = head->next };
    invariant
    values == \Cons( head->value, Tail.values );
  }
}
*/


