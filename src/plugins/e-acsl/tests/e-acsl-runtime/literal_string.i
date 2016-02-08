/* run.config
   COMMENT: literal string
   COMMENT: no diff
   COMMENT: no diff
*/

int main(void);

char *T = "bar";
int G = 0;

void f(void) {
  /*@ assert T[G] == 'b'; */ ;
  G++;
}

char *S = "foo";
char *S2 = "foo2";
int IDX = 1;
int G2 = 2;

int main(void) {
  char *SS = "ss";
  /*@ assert S[G2] == 'o'; */
  /*@ assert \initialized(S); */
  /*@ assert \valid_read(S2); */
  /*@ assert ! \valid(SS); */
  f();
  return 0;
}

char *U = "baz";
