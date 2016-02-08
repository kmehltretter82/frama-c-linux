/* run.config
   COMMENT: pointer to an empty struct
   COMMENT: no diff
*/

struct toto {};

int main() {
  struct toto s;
  //@ assert \valid(&s);
  struct toto *p;
  p = &s;
  //@ assert \valid(p);
  return 0;
}
