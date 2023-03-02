#include <limits.h>
#include <stdlib.h>

int rand_max_is = RAND_MAX;
/* NB: MB_LEN_MAX is the maximal value of MB_CUR_MAX;
   however, the current Frama-C libc is not equipped to
   fully deal with a non-constant MB_CUR_MAX
*/
size_t mb_cur_max_is = ((size_t)MB_LEN_MAX);
