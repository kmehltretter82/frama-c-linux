/* run.config
   CMXS: Type_of_term
   OPT: -load-module %{dep:Type_of_term.cmxs} -print
*/

int t [42];

struct S { int x; int y[]; } s;

/*@ assigns *(p+(..)), t[..], s[..].x, s[..].y[..]; 
*/
void f(int *p, struct S* s);

int main() {
  f(t,&s);
  return 0;
}
