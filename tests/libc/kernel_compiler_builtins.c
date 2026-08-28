/* run.config
   STDOPT: +"-machdep gcc_x86_64 -cpp-extra-args='-include @FRAMAC_SHARE@/kernel-models/compiler_builtins.h'"
*/

volatile unsigned int unknown_uint;
volatile unsigned long unknown_ulong;
volatile unsigned long long unknown_ullong;

int main(void)
{
  unsigned int ui = unknown_uint;
  unsigned long ul = unknown_ulong;
  unsigned long long ull = unknown_ullong;

  if (ui != 0) {
    int leading = __builtin_clz(ui);
    int trailing = __builtin_ctz(ui);
    //@ assert 0 <= leading < 8 * sizeof(ui);
    //@ assert 0 <= trailing < 8 * sizeof(ui);
  }

  if (ul != 0) {
    int leading = __builtin_clzl(ul);
    int trailing = __builtin_ctzl(ul);
    //@ assert 0 <= leading < 8 * sizeof(ul);
    //@ assert 0 <= trailing < 8 * sizeof(ul);
  }

  if (ull != 0) {
    int leading = __builtin_clzll(ull);
    int trailing = __builtin_ctzll(ull);
    //@ assert 0 <= leading < 8 * sizeof(ull);
    //@ assert 0 <= trailing < 8 * sizeof(ull);
  }

  return 0;
}

_Static_assert(sizeof(__int128_t) == 16,
               "GCC's signed 128-bit alias is modeled");
_Static_assert(sizeof(__uint128_t) == 16,
               "GCC's unsigned 128-bit alias is modeled");
