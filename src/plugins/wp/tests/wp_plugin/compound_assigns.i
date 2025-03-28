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

/*@
  requires \valid(p);
  requires \valid(q);
  requires p==q || \separated(p,q);
  assigns *p, *q;

  ensures P: *p == \old(*q);
  ensures Q: *q == \old(*p);

  region PF: p->f, PG: p->g;
  region QF: q->f, QG: q->g;
*/
void swapA(struct A *p, struct A *q)
{
   struct A tmp = *p;
   *p = *q;
   *q = tmp;
   return;
}
