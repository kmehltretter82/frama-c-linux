/* run.config
MODULE: @PTEST_NAME@.cmxs
OPT: -print
*/


// This predicate is modified by expr_to_term.ml plugin to compare
// the assigned l-value or condition at provided stmt id with the logical term

/*@ predicate int_eq(int logical, int from_stmt_id) = logical == from_stmt_id; */

int x[10];

struct S { int y; int z; } s;

int t;

/*@ ensures int_eq(*(int*)((unsigned)0x1 + 0x2),(int)0); */
int f() {

*(int *)((unsigned)0x1 + 0x2) = 0;
return 0;
}

/*@ ensures int_eq(x[0], (int)1);
    ensures int_eq(s.y, (int)2);
    ensures int_eq(s.z, (int)3);
    ensures int_eq(t,(int)4);
*/
int main() {
  x[0] = 1;
  s.y = 2;
  s.z = 3;
  t = 4;
}

/*@ ensures int_eq((int)(t!=0 ? 0 : 1),(int)5); */
int g() {
  if (!t) return 2; else return 3;
}

/*@ ensures int_eq((int)(t<5 ? 1 : 0),(int)6); */
int h() {
  if (t<5) return 2; else return 3;
}
