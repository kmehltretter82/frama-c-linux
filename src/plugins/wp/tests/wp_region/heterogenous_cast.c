/*@
    assigns *p;
@*/
void g (int *p) {
  *p = 42;
  short *q = (short*) p;
  q[0] = -1;
  q[1] = -1;
  //@ assert *p == -1;
}
