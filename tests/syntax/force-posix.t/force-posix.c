/* should be an error in the last case because _POSIX_C_SOURCE has been forcibly undefined */
#include <unistd.h>

long f() { return _POSIX_C_SOURCE; }

long g() { return _POSIX_VERSION; }
