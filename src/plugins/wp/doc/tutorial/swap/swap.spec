/*@
  requires \valid(p);
  requires \valid(q);
  requires \separated(p,q);

  assigns *p;
  assigns *q;

  ensures *p == \old(*q);
  ensures *q == \old(*p);
*/
void swap(value_type* p, value_type* q);