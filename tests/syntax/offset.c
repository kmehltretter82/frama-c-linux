/* run.config
   COMMENT: dependency to FRAMA-C share directory is implicit
   OPT: -cpp-extra-args="-I@FRAMAC_SHARE@/libc" -print
*/
#include "__fc_define_off_t.h"

off_t x = 0;

off64_t y = 0;
