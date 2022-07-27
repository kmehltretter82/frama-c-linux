/* run.config*
BIN: @PTEST_NAME@.sarif.unfiltered
OPT: -eva -then -mdr-sarif-deterministic -mdr-gen sarif -mdr-out ./@PTEST_NAME@.sarif.unfiltered
EXECNOW: LOG @PTEST_NAME@.sarif sed -e "s:@PTEST_SESSION@:PTEST_SESSION:" %{dep:@PTEST_NAME@.sarif.unfiltered} > @PTEST_NAME@.sarif 2> @NULL
*/
#include "string.c"

int main() { }
