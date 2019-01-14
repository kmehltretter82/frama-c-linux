#include <stropts.h>

int main(){
  int fd1 = 1;
  int request1 = 0;
  int r1 = ioctl(fd1, request1); // without 3rd argument
  char arg = 42;
  int r2 = ioctl(fd1, request1, &arg); // with 3rd argument
  return 0;
}
