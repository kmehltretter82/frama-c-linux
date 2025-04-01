/* run.config
   OPT: -wp-model typed  -wp-msg-key print-generated
   OPT: -wp-model bytes  -wp-msg-key print-generated
   OPT: -wp-model region -wp-msg-key print-generated
*/

/* run.config_qualif
   OPT: -wp-model typed
   OPT: -wp-model bytes
   OPT: -wp-model region
*/

struct A {
   int f[4];
   double g;
};

/*@ ghost struct A HEAP[10]; */

/*@
  requires \valid(p);
  requires \valid(q);
  requires p==q || \separated(p,q);
  assigns *p, *q;
  region HEAP, *p, *q;
  ensures P: *p == \old(*q);
  ensures Q: *q == \old(*p);
*/
void swapA(struct A *p, struct A *q)
{
   /*@ ghost int a = p->f[0]; */
   /*@ ghost int b = q->f[0]; */
   /*@ ghost double c = p->g; */
   /*@ ghost double d = q->g; */
   struct A tmp = *p;
   *p = *q;
   *q = tmp;
   return;
}
