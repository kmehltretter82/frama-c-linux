/* run.config
   COMMENT: separate tracking of string constants
*/

const char *f = "the cat";
const char *s = "the dog and the cat";

#include <stdlib.h>

char *strdup(const char*);

int main(int argc, const char **argv) {
  s++;
  f++;
  return 0;
}
