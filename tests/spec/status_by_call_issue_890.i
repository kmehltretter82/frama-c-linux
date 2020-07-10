/* run.config
   MODULE: @PTEST_DIR@/@PTEST_NAME@.cmxs
*/

struct list { struct list *next; };

/*@ axiomatic Ax { predicate P(struct list * root) ; } */

/*@ requires P(l); @*/
int len(struct list * l){
  return (l == (void*)0) ? 0 : 1 + len(l->next);
}
