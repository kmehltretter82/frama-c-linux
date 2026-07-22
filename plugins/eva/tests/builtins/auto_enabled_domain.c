/* run.config*
   STDOPT: #"-eva-secure-flow"
 */

/* Tests builtins with a domain enabled by a parameter other than -eva-domains.
   -eva-secure-flow automatically enables the taint domain, and this modifies
   the value of the -eva-domains parameter at the start of the analysis.
   This must not clear the builtins table built beforehand: no builtin for sqrt
   as the function has no spec, but builtin for strlen as it has a spec. */

#include <stddef.h>
#include "__fc_string_axiomatic.h"

/*@ requires valid_string_s: valid_read_string(s);
    assigns \result \from indirect:s[0..]; */
extern size_t strlen (const char *s);

extern double sqrt(double x);

int main(void) {
  double d;
  d = sqrt(2.);
  d = sqrt(3.);
  size_t s;
  s = strlen("abcd");
  s = strlen("abracadabra");
  return 0;
}
