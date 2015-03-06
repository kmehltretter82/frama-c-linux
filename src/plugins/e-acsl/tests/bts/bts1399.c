/* run.config
   COMMENT: complex fields and indexes + potential RTE in \initialized
   STDOPT: #"-cpp-extra-args=\"-I`@frama-c@ -print-share-path`/libc\"" +"-val-builtin __malloc:Frama_C_alloc_size -val-builtin __free:Frama_C_free"
   EXECNOW: LOG gen_bts1399.c BIN gen_bts1399.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/bts/bts1399.c -e-acsl -then-on e-acsl -print -ocode ./tests/bts/result/gen_bts1399.c > /dev/null && ./gcc_test.sh bts1399
   EXECNOW: LOG gen_bts13992.c BIN gen_bts13992.out @frama-c@ -e-acsl-share ./share/e-acsl ./tests/bts/bts1399.c -e-acsl-gmp-only -e-acsl -then-on e-acsl -print -ocode ./tests/bts/result/gen_bts13992.c > /dev/null && ./gcc_test.sh bts13992
*/

#include "stdlib.h"

extern void *malloc(size_t p);

struct spongeStateStruct {
   unsigned char __attribute__((__aligned__(32))) state[1600 / 8] ;
   unsigned char __attribute__((__aligned__(32))) dataQueue[1536 / 8] ;
   unsigned int bitsInQueue ;
} __attribute__((__aligned__(32)));
typedef struct spongeStateStruct spongeState;

int main(void) {
  spongeState* state = (spongeState*) malloc(sizeof(spongeState));
  state->bitsInQueue = 16;
  
  /*@ assert
      ! \initialized(&state->dataQueue[state->bitsInQueue/(unsigned int)8]);
    */

  free(state);
  return 0;
}

