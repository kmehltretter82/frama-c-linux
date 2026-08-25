#include <string.h>

int main() {
  const int x = 42;
  int y;
  int *res = memcpy(&y, &x, sizeof(x));
  //@ assert res == &y;
  //@ assert *res == 42;
}
