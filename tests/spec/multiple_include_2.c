/* run.config
 EXIT: 1

   OPT: -kernel-warn-key=annot-error=active -print tests/spec/multiple_include_1.c
*/

#include "multiple_include.h"

/*@ requires p(x); */
void bar(int x) { i+=x; return; }
