#include <sys/uio.h>
#include <unistd.h>
#include <fcntl.h>

int main() {
  char *str = "A small string";
  char *empty_buf = 0;
  char buf[10] = "\n\n\nbuffer";
  char buf2[14];
  struct iovec v[4] =
    {
     {str, 15},
     {empty_buf, 0},
     {buf, 10},
     {buf2, 14},
    };
  int fd = open("/tmp/uio.txt", O_WRONLY | O_CREAT, 0660);
  if (fd < 0) return 1;
  ssize_t w = writev(fd, v, 3);
  close(fd);
  fd = open("/tmp/uio.txt", O_RDONLY);
  ssize_t r = readv(fd, v+2, 2);
  close(fd);
  return w + r;
}
