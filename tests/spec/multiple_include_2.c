/* run.config
   DEPS: multiple_include.h
   OPT: -kernel-warn-key=annot-error=active -print %{dep:multiple_include_1.c} -journal-disable
*/
#include "multiple_include.h"
/*@ requires p(x); */
void bar(int x) { i+=x; return; }
