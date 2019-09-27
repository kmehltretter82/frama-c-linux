#include <string.h>

int main(void){
  int s1[10] = { 0 } ;
  int s2[10] = { 0 };

  int res = memcmp(s1, s2, sizeof(s1));
}