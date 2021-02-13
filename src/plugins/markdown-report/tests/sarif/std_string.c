/* run.config*
LOG: @PTEST_NAME@.sarif
OPT: -eva -then -mdr-sarif-deterministic -mdr-gen sarif -mdr-out @PTEST_DIR@/result/@PTEST_NAME@.sarif
*/

#include "string.c"

int main() { }
