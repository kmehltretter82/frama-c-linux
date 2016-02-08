/* run.config
   COMMENT: \result
   COMMENT: no diff
   COMMENT: no diff
*/

/*@ ensures \result == (int)(x - x); */
int f(int x) { 
  x = 0; 
  return x; }

int Y = 1;

// does not work since it is converted into \result == \old(x) and, 
// in this particular case, the pre-state and the post-state are the same and 
// it does not work yet (related to issue in at.i).
// /*@ ensures \result == x; */ 
/*@ ensures \result == Y; */
int g(int x) { 
  return x; 
}

/*@ ensures \result == 0; */
int h() { return 0; }

int main(void) {
  f(1);
  g(Y);
  h();
  return 0;
}
