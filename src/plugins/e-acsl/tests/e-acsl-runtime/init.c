/* run.config
   COMMENT: initialization of globals (bts #1818)
   COMMENT: no diff
   COMMENT: no diff
*/

int a = 0, b;

int main(void) {
  int *p = &a, *q = &b;
  /*@assert \initialized(&b) ; */
  /*@assert \initialized(q) ; */
  /*@assert \initialized(p) ; */
}
