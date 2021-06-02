/* run.config
   COMMENT: Test `strcpy` and `strncpy` E-ACSL built-ins
*/

#include "../utils/signalled.h"
#include <string.h>
#include <stdlib.h>

int main(int argc, const char **argv) {
  char empty_str[1] = "";
  char *const_str = "abcd";
  char *src = strdup("abcd");
  char *dest1 = malloc(5);
  char *dest2 = malloc(4);
  char dest3[256] = "abcd";
  size_t len = 0;

  char *unalloc_str = malloc(5); char* _barrier = malloc(1); free(unalloc_str);

  /* strcpy */
  OK(strcpy(dest1, src)); // heap allocated, sufficient space [ok]
  OK(strcpy(empty_str, "")); // copy empty string [ok]
  ABRT(strcpy(dest2, src)); // heap allocated, insufficient space [abort]
  ABRT(strcpy(unalloc_str, src)); // unallocated [abort]
  ABRT(strcpy(const_str, src)); // read-only in dest [abort]
  OK(strcpy(src, const_str)); // read-only in src [ok]
  ABRT(strcpy(src, src)); // same address, overlapping [abort]
  OK(strcpy(dest3 + 5, dest3)); // same string, non-overlapping [ok]
  ABRT(strcpy(dest3 + 4, dest3)); // same string, overlapping [abort]

  /* strncpy */
  OK(strncpy(dest1, src, 5)); // heap allocated, sufficient space [ok]
  ABRT(strncpy(dest1, src, 6)); // heap allocated, insufficient space [abort]
  ABRT(strncpy(unalloc_str, src, 5)); // unallocated [abort]
  ABRT(strncpy(const_str, src, 5)); // read-only in dest [abort]
  OK(strncpy(src, const_str, 5)); // read-only in src [ok]
  ABRT(strncpy(src, src, 5)); // same address, overlapping [abort]
  OK(strncpy(dest3 + 5, dest3, 5)); // same string, non-overlapping [ok]
  ABRT(strncpy(dest3 + 4, dest3, 5)); // same string, overlapping [abort]

  free(src);
  free(dest1);
  free(dest2);
  return 0;
}
