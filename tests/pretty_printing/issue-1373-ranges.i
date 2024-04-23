/* run.config
   STDOPT:
*/

struct foo { char bar[4]; };

/*@ assigns x->bar[name_range1:(0..3)] \from x->bar[0..3]; */
int f(struct foo* x);

void main() {
  int a = 0;
  //@ assert \subset(a, (0..1));
  //@ assert \subset(a, (name_range2:(0..2)));
}
