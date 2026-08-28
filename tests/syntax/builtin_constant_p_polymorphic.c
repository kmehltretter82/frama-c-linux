/* run.config
   OPT: -machdep gcc_x86_64 -print
*/

int pointer_is_constant(void *pointer)
{
  return __builtin_constant_p(pointer);
}

int integer_is_constant(int value)
{
  return __builtin_constant_p(value);
}

int nonconstant_fallback(int value);
int __builtin_clz(unsigned int value);
int __builtin_clzl(unsigned long value);
int __builtin_clzll(unsigned long long value);
int __builtin_ctz(unsigned int value);
int __builtin_ctzl(unsigned long value);
int __builtin_ctzll(unsigned long long value);

int constant_conditional_array[
  __builtin_constant_p(4 < 2 ? 4 : 2)
    ? (4 < 2 ? 4 : 2)
    : nonconstant_fallback(2)
];

int clz_int[__builtin_clz(1U)];
int clz_long[__builtin_clzl(1UL)];
int clz_long_long[__builtin_clzll(4 < 2 ? 4ULL : 1ULL)];

int ctz_int[__builtin_ctz(8U)];
int ctz_long[__builtin_ctzl(8UL)];
int ctz_long_long[__builtin_ctzll(8ULL)];
