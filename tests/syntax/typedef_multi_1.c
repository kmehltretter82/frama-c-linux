/* run.config
   DEPS: typedef_multi.h
   CMXS: typedef_multi
   OPT: -load-module %{dep:typedef_multi.cmxs} %{dep:typedef_multi_2.c}
*/
#include "typedef_multi.h"

void f () {  while(x<y) x++; }
