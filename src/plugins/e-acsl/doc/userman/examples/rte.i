/*@ behavior yes:
     assumes x % y == 0;
     ensures \result == 1;
    behavior no:
     assumes x % y != 0;
     ensures \result == 0; */
int divide(int x, int y) {
  return x % y == 0;
}

int main(void) {
  divide(2, 0);
  return 0;
}
