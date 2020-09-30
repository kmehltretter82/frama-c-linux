/* run.config
   DEPS: @PTEST_NAME@.h
   STDOPT: +"%{dep:@PTEST_NAME@_1.c}"
*/

#include "merge_bts938.h"
//@ ensures test:\true;
int main(void) { }
