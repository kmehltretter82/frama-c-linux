/* run.config
   OPT: -machdep gcc_arm64
*/

#ifndef __aarch64__
# error "gcc_arm64 must define __aarch64__"
#endif

#ifndef __AARCH64EL__
# error "gcc_arm64 must select little-endian AArch64"
#endif

#ifndef __CHAR_UNSIGNED__
# error "the generated GCC AArch64 model must use unsigned plain char"
#endif

_Static_assert(sizeof(void *) == 8, "AArch64 pointers are 64-bit");
_Static_assert(sizeof(long) == 8, "AArch64 uses the LP64 data model");
_Static_assert(sizeof(long double) == 16,
               "GCC AArch64 long double occupies 16 bytes");
_Static_assert((char)-1 > 0, "plain char is unsigned for this compiler");

int gcc_arm64_machdep(void)
{
  return __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__;
}
