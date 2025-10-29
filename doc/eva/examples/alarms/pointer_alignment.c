void main(void) {
  char c[4];
  char _Alignas(_Alignof(short)) c2[4];
  int i;
  int *p1 = (int *)c;
  int *p2 = (int *)c2;
  short *p3 = (short *)c2;
  char *p4 = (char *)&i;
}
