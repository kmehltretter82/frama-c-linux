/* run.config*
  STDOPT: #""
*/

#include <stdlib.h>
#include <string.h>

volatile v;

static void copy(void *dst_, void *src_, size_t off, size_t len)
{
  char *dst = dst_;
  char *src = src_;
  memcpy(dst + off, src + off, len);
}

// Bug reported by Trust-in-Soft
int main1(void) {
  int *t[2];

  /*@ slevel 2; */
  for (int i = 0; i < 2; i++)
    t[i] = malloc(0x80);

  int *p;
  size_t n = sizeof(void *);
  copy(&p, &t[1], 0, 1);
  copy(&p, &t[0], 1, n - 1);
  *p = 42; /* p should not be a valid pointer */
  int r = *p;
  return r;
}


void main2() { // Test performance of iterating on strong malloced variables
  int t[1000];
  int i = malloc(sizeof(int));

  //@ slevel 10000;
  for (i = 0; i < 800; i++) {
    t[i] = i;
  }
}

void main() {
  main1();
  main2();
}
