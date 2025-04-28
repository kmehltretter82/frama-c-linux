/* run.config
   MACRO: DISPLAY -wp-msg-key print-generated
   OPT: -wp-model typed  @DISPLAY@
   OPT: -wp-model region @DISPLAY@
   OPT: -wp-model bytes  @DISPLAY@
   OPT: -wp-model typed  @DISPLAY@ -wp-no-havoc
   OPT: -wp-model region @DISPLAY@ -wp-no-havoc
   OPT: -wp-model bytes  @DISPLAY@ -wp-no-havoc
*/

/* run.config_qualif
   MACRO: TIME -wp-timeout 10
   MACRO: TIP -wp-strategy Unfold -wp-prover tip,alt-ergo -wp-script dry
   OPT: -wp-model typed  @TIME@
   OPT: -wp-model region @TIME@ @TIP@
   OPT: -wp-model bytes  @TIME@ @TIP@ -wp-skip-fct copy
   OPT: -wp-model typed  @TIME@       -wp-no-havoc
   OPT: -wp-model region @TIME@ @TIP@ -wp-no-havoc
   OPT: -wp-model bytes  @TIME@ @TIP@ -wp-no-havoc -wp-skip-fct copy
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
  requires p==q || \separated(p,q);
  assigns *p, *q;
  region HEAP, *p, *q;
  ensures P: *p == \old(*q);
  ensures Q: *q == \old(*p);
*/
void swap(struct A *p, struct A *q)
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

/*@
  requires \separated(p,q,r);
  assigns *p, *q, *r;
  behavior Left:
    assumes side;
    ensures CopyQ: *p == \old(*q);
    ensures KeepQ: *q == \old(*q);
    ensures SaveR: *r == \old(*p);
  behavior Right:
    assumes !side;
    ensures CopyR: *p == \old(*r);
    ensures SaveQ: *q == \old(*p);
    ensures KeepR: *r == \old(*r);
*/
void copy(int side, struct A *p, struct A *q, struct A *r)
{
   // Populate region map with struct fields
   /*@ ghost int a = p->f[0]; */
   /*@ ghost int b = q->f[0]; */
   /*@ ghost int c = r->f[0]; */
   /*@ ghost double d = p->g; */
   /*@ ghost double e = q->g; */
   /*@ ghost double f = r->g; */
   struct A *w = side ? r : q;
   struct A *s = side ? q : r;
   /*@ ghost L: ; */
   *w = *p;
   //@ assert Kept: *s == \at(*s,L);
   *p = *s;
   //@ assert Kept: *s == \at(*s,L);
}
