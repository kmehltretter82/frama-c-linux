/* run.config
   OPT: -machdep gcc_x86_64 -print
*/

_Static_assert(__builtin_strlen("kernel") == 6,
               "literal length is folded");
_Static_assert(__builtin_strlen("a\0trailing") == 1,
               "length stops at the first NUL byte");

unsigned long folded_strlen(void)
{
  return __builtin_strlen("Frama-C Linux");
}
