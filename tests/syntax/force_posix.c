/* run.config
  COMMENT: only the first value make sense, the other two tests are there to
  COMMENT: check that the preprocessor passes the value to _POSIX_C_SOURCE as expected.
  OPT: -cpp-extra-args="-D__FC_FORCE_POSIX_C_SOURCE=199309L" -print
  OPT: -cpp-extra-args="-D__FC_FORCE_POSIX_C_SOURCE=0" -print
  OPT: -cpp-extra-args="-D__FC_FORCE_POSIX_C_SOURCE=-2" -print
EXIT:1
FILTER: sed -e "s|$TMPDIR/[^ ]*|/tmp/TEMPNAME|g" -e "s|$(realpath $(pwd)/../../../..)|FC_HOME|g"
  OPT:-cpp-extra-args="-D__FC_FORCE_POSIX_C_SOURCE="
*/

/* should be an error in the last case because _POSIX_C_SOURCE has been forcibly undefined */
#include <unistd.h>

long f() { return _POSIX_C_SOURCE; }

long g() { return _POSIX_VERSION; }
