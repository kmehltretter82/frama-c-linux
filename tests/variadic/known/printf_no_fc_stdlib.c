/* run.config
   STDOPT: #"-no-frama-c-stdlib" +"-kernel-msg-key=\"-variadic\""
*/
#include <stdio.h>

int main() {
  printf("dummy call: %d\n", 1);
  printf("other call with more args: %d and %d\n", 2, 3);
}
