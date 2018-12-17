/* run.config*
   OPT: -no-autoload-plugins -load-module inout,eva -big-ints-hex 256 -val @VALUECONFIG@ -journal-disable
*/
#include "__fc_builtin.h"

extern unsigned short s;

void f1(void) {
  int or1, or2, or3, or4, or5;
  int and1, and2, and3, and4, xor1, xor2;
  unsigned int uand1, uand2, uand3, uand4, uand5;
  int a,b,c,d,e;

  a = Frama_C_interval(3,17);
  b = Frama_C_interval(-3,17);
  c = Frama_C_interval(13,27);
  or1 = a | b;
  or2 = a | c;
  or3 = b | c;

  and1 = a & b;
  and2 = a & c;
  and3 = b & c;

  uand4 = 0xFFFFFFF8U & (unsigned int) c;

  xor1 = a ^ a;
  xor2 = a ^ b;

  unsigned i1 = s * 2;
  unsigned i2 = s * 4;
  unsigned v1 = i1 & i2;
  unsigned v2 = i1 | i2;
  
  unsigned mask07 = (16 * s + 13) & 0x7;
  unsigned mask0f = (16 * s + 13) & 0xF;
  unsigned mask1f = (16 * s + 13) & 0x1F;
}

void f2(void) {
  int x = Frama_C_interval(62,110) & ~(7);
}

volatile unsigned char t[3];

void f3(void) {
  int x = (t[0] & 0x10 ? -1^255 : 0) | t[1];
  int y = (t[0] & 0x20 ? -1^255 : 0) | t[2];
}

void main(void) {
  f1();
  f2();
  f3();
}

