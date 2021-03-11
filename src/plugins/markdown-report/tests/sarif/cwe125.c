/* run.config  NOFRAMAC: use execnow for proper sequencing of executions
PLUGIN: markdown-report eva inout
EXECNOW: LOG @PTEST_NAME@.parse.log LOG @PTEST_NAME@.parse.err LOG @PTEST_NAME@_parse.sav @frama-c@ -save @PTEST_NAME@_parse.sav > @PTEST_NAME@.parse.log 2> @PTEST_NAME@.parse.err
EXECNOW: LOG @PTEST_NAME@.eva.log   LOG @PTEST_NAME@.eva.err   LOG @PTEST_NAME@_eva.sav   @frama-c-cmd@ -load %{dep:@PTEST_NAME@_parse.sav} -eva -save @PTEST_NAME@_eva.sav > @PTEST_NAME@.eva.log 2> @PTEST_NAME@.eva.err
EXECNOW: LOG @PTEST_NAME@.sarif.log LOG @PTEST_NAME@.sarif.err LOG @PTEST_NAME@.sarif     @frama-c-cmd@ -load %{dep:@PTEST_NAME@_eva.sav} -then -mdr-out @PTEST_NAME@.sarif -mdr-gen sarif -mdr-no-print-libc -mdr-sarif-deterministic > @PTEST_NAME@.sarif.log 2> @PTEST_NAME@.sarif.err
*/
#include "__fc_builtin.h"

#define LENGTH 10

int getValueFromArray(int *array, int len, int index) {

int value;

// check that the array index is less than the maximum

// length of the array
if (index < len) {

// get the value at the specified index of the array
value = array[index];
}
// if array index is invalid then output error message

// and return value indicating error
else {
printf("Value is: %d\n", array[index]);
value = -1;
}

return value;
}

int main() {
  int arr[LENGTH] = { 0 };
  int test = Frama_C_interval(-LENGTH,LENGTH);
  return getValueFromArray(arr,LENGTH,test);
}
