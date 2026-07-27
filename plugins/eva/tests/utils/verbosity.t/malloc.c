#include <stdlib.h>

void main (void) {
  /* Emit message with [malloc:new] key. */
  int *p = malloc(sizeof(int));
  if (p != NULL) *p = 42;
  /* Emit message with [malloc] key. */
  free(p);
}
