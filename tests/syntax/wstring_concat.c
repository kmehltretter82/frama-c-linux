/* run.config*
TIMEOUT: 10
OPT: -eva
*/

#include <wchar.h>
#include <stdio.h>

#define d(a) a a
#define dd(a) d(d(a))
#define ddd(a) dd(dd(a))
#define dddd(a) ddd(ddd(a))
#define ddddd(a) dddd(dddd(a))

const wchar_t test[] = ddddd(L"a");

int main() { printf("length: %zu\n",wcslen(test)); }
