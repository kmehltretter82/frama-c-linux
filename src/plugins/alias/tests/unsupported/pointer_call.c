int f () {
  return 0;
}

int main () {
  int (*p)() = &f;
  return ((*p)());
}
