/* run.config
   COMMENT: bts #1478 about wrong detection of initializers in pre-analysis
   EXECNOW: LOG gen_bts1478.c BIN gen_bts1478.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1478.c -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts1478.c > /dev/null && ./gcc_test.sh bts1478
   EXECNOW: LOG gen_bts14782.c BIN gen_bts14782.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/e-acsl-runtime/bts1478.c -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/e-acsl-runtime/result/gen_bts14782.c > /dev/null && ./gcc_test.sh bts14782
*/

int global_i = 0;
int* global_i_ptr = &global_i;

/*@ requires global_i == 0;
    requires \valid(global_i_ptr);
    requires global_i_ptr == &global_i; */
void loop(void) { }

int main(void) {
  loop();
  return 0;
}
