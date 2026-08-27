/* run.config
   OPT: -print -machdep gcc_x86_64 -cpp-extra-args=-DEXPECT_INT128
   OPT: -print -machdep x86_64
*/

#ifdef EXPECT_INT128
# if __SIZEOF_INT128__ != 16
#  error invalid __SIZEOF_INT128__ value
# endif
unsigned __int128 wide_integer;
__signed__ __int128 signed_wide_integer;
#else
# ifdef __SIZEOF_INT128__
#  error __SIZEOF_INT128__ requires a GCC-compatible machdep
# endif
unsigned long long ordinary_integer;
#endif
