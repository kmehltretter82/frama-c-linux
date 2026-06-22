/* run.config
OPT: %{dep:@FRAMAC_SHARE@/libc/fenv.c} -print
*/

#include <errno.h>
#include <fenv.h>
#include <error.h>

void f() {
  fenv_t env;
  if (fegetenv(&env)) {
    error(1,EINVAL,"error getting fenv");
  }
  if (fesetenv(&env)) {
    error(1,EINVAL,"error setting fenv");
  }
}
