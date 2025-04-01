/* run.config
   MACRO: DISPLAY -wp-msg-key print-generated
   OPT: -wp-model typed  @DISPLAY@
   OPT: -wp-model bytes  @DISPLAY@
   OPT: -wp-model region @DISPLAY@
*/

/* run.config_qualif
   MACRO: TIP -wp-strategy Unfold -wp-prover tip,alt-ergo -wp-script dry -wp-timeout 5
   OPT: -wp-model typed  @TIP@
   OPT: -wp-model bytes  @TIP@
   OPT: -wp-model region @TIP@
*/

struct A {
   int f[4];
   double g;
};

/*@
  strategy Unfold:
    \tactic("Wp.unfold", \ingoal( EqS1_A(_,_) ));
*/

// Disable singleton region
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
   // Populate region map with struct fields
   /*@ ghost int a = p->f[0]; */
   /*@ ghost int b = q->f[0]; */
   /*@ ghost double c = p->g; */
   /*@ ghost double d = q->g; */
   struct A tmp = *p;
   *p = *q;
   *q = tmp;
   return;
}
