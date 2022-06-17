#include "unistd.c"

int main() {
  int argc = 4;
  char *argv[] = {"program_name", "-this", "is a", "Test0"};
  int r = getopt(argc, argv, "tes:");
  return 0;
}
