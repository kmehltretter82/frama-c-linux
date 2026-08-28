/* run.config
   OPT:
*/

#include <stdarg.h>

unsigned long use_local_stdarg_macro_names(void)
{
  unsigned long va_start = 1;
  unsigned long va_end = 2;
  unsigned long va_arg = 3;
  unsigned long va_copy = 4;

  va_start += va_end;
  va_arg += va_copy;
  return va_start + va_arg;
}
