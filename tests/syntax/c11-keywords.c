/* run.config
   EXIT: 1
   STDOPT: #"-cpp-extra-args=-DCOMPLEX"
   STDOPT: #"-cpp-extra-args=-DIMAGINARY"
   STDOPT: #"-cpp-extra-args=-DDECIMAL"
   STDOPT: #"-cpp-extra-args=-DINT128"
   STDOPT: #"-cpp-extra-args=-DUINT128"
*/

int main(void) {
#ifdef COMPLEX // see also tests/syntax/alignof_typing_constrains.c "#ifdef TEST_COMPLEX"
  double _Complex c = 1;
#endif

#ifdef IMAGINARY
  //Note: GCC/Clang do not yet support _Imaginary
  double _Imaginary im = 0;
#endif

#ifdef DECIMAL
  _Decimal32 d32 = 0.25;
#endif

#ifdef INT128
  __int128 i128 = -1; // Not C11, but GNU extension
#endif

#ifdef UINT128
  __uint128_t ui128 = 9; // Not C11, but GNU extension
#endif

  return 0;
}
