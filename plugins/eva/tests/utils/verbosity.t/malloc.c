#include <stdlib.h>

void main (void) {
  int *p;
  //@ loop unroll 2;
  for (int i = 0; i < 2; i++) {
    /* First iteration emits allocation message with [malloc:new] key.
       Second iteration emits resizing message with [malloc] key. */
    p = malloc(i * sizeof(int));
  }
}
