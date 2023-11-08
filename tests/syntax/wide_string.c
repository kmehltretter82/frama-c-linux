#include <wchar.h>

_Static_assert(sizeof(L"AA") == 3*sizeof(wchar_t), "Incorrect sizeof behaviour");

int main(void){}
