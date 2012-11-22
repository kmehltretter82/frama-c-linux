/* run.config
   COMMENT: global literal string: moving them and their dependencies for 
   COMMENT: proper initialization
   EXECNOW: LOG gen_global_literal_string.c BIN gen_global_literal_string.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/global_literal_string.i -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_global_literal_string.c > /dev/null && ./gcc_test.sh global_literal_string
   EXECNOW: LOG gen_global_literal_string2.c BIN gen_global_literal_string2.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/global_literal_string.i -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_global_literal_string2.c > /dev/null && ./gcc_test.sh global_literal_string2
*/

int main(void);

char *T = "bar";

int G = 0;

void f(void) { 
  /*@ assert T[G] == 'b'; */ ;
  G++;
}

char *S = "foo";
int IDX = 1;

int G2 = 2;

int main(void) {
  /*@ assert S[G2] == 'o'; */
  // /*@ assert \initialized(S); */
  return 0;
}

char *U = "baz";
