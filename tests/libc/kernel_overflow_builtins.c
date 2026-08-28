/* run.config
   STDOPT: +"-machdep gcc_x86_64 -cpp-extra-args='-include @FRAMAC_SHARE@/kernel-models/compiler_builtins.h'"
*/

int main(void)
{
  unsigned long umax = ~0UL;
  unsigned long ures;
  _Bool overflow;

  overflow = __builtin_add_overflow(umax, 1UL, &ures);
  //@ assert overflow && ures == 0;

  overflow = __builtin_sub_overflow(0UL, 1UL, &ures);
  //@ assert overflow && ures == umax;

  overflow = __builtin_mul_overflow(umax, 2UL, &ures);
  //@ assert overflow && ures == umax - 1;

  overflow = __builtin_mul_overflow(6UL, 7UL, &ures);
  //@ assert !overflow && ures == 42;

  unsigned int imax = ~0U >> 1;
  int smax = (int)imax;
  int smin = -smax - 1;
  int sres;

  overflow = __builtin_add_overflow(smax, 1, &sres);
  //@ assert overflow && sres == smin;

  overflow = __builtin_sub_overflow(smin, 1, &sres);
  //@ assert overflow && sres == smax;

  overflow = __builtin_mul_overflow(smax, 2, &sres);
  //@ assert overflow && sres == -2;

  return 0;
}
