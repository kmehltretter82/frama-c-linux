struct S { int f, g; } ;

void job(struct S a) {
  struct S s[4] = { [1]=a, 42 };
}
