/* run.config
   COMMENT: Test `strlen` E-ACSL built-ins
*/

#include "../utils/signalled.h"
#include <string.h>
#include <stdlib.h>

#define EQ(l,r) if (l != r) abort();

int main(int argc, const char **argv) {
  int len;
  char *empty_str = "";
  char *heap_str = strdup("the cat");
  char stack_str[] = "the dog";
  char *const_str = "the hog";

  OK(EQ(len = strlen(empty_str),0)); // strlen on a valid (zero-length) string [ok]
  OK(EQ(len = strlen(heap_str),7)); // strlen on a heap string [ok]
  OK(EQ(len = strlen(stack_str),7)); // strlen on a stack string [ok]
  OK(EQ(len = strlen(const_str),7)); // strlen on a const string [ok]

  heap_str[7] = 'a';
  stack_str[7] = 'a';
  ABRT(EQ(len = strlen(heap_str),7)); // strlen on unterminated heap string [abort]
  ABRT(EQ(len = strlen(stack_str),7)); // strlen on unterminated stack string [abort]
  free(heap_str);
  ABRT(EQ(len = strlen(heap_str),7)); // strlen on invalid heap string [abort]
  return 0;
}


