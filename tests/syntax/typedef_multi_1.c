/* run.config
   DEPS: typedef_multi.h
   MODULE: typedef_multi
   STDOPT: +"-no-print" +"%{dep:typedef_multi_2.c}"
*/
#include "typedef_multi.h"

void f () {  while(x<y) x++; }
