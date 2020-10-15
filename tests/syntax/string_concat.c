/* run.config*
TIMEOUT: 600
PLUGIN: @EVA_CONFIG@
OPT: -eva
*/
#include <string.h>
#include <stdio.h>

#define d(a) a a
#define dd(a) d(d(a))
#define ddd(a) dd(dd(a))
#define dddd(a) ddd(ddd(a))
#define ddddd(a) dddd(dddd(a))

const char test[] = ddddd("a");

int main() { printf("length: %zu\n",strlen(test)); }
