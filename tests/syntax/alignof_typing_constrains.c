/* run.config
   OPT:
   EXIT: 1
   STDOPT: #"-cpp-extra-args=-DFAIL_FUNCTION"
   STDOPT: #"-cpp-extra-args=-DFAIL_INCOMPLETE"
*/

struct basic_s
{
  int x;
  char y;
};

struct nested_s
{
  struct basic_s b;
  int array[4];
  float f;
};

union basic_u {
  int x ;
  char c[4];
};

union nested_u {
  union { int i ; unsigned u ; };
  char c[8];
};

enum E { A, B, C, D }; /* underlying type for default machdep: int */

void c11_6_2_5_6(void) // _Alignof(t) == _Alignof(unsigned t)
{
  _Static_assert(_Alignof(char) == _Alignof(signed char));
  _Static_assert(_Alignof(char) == _Alignof(unsigned char));
  _Static_assert(_Alignof(short) == _Alignof(unsigned short));
  _Static_assert(_Alignof(int) == _Alignof(unsigned int));
  _Static_assert(_Alignof(long) == _Alignof(unsigned long));
  _Static_assert(_Alignof(long long) == _Alignof(unsigned long long));
}

#ifdef TEST_COMPLEX
#include <complex.h>
void c11_6_2_5_13(void)
{
  _Static_assert(_Alignof(float) == _Alignof(float complex));
  _Static_assert(_Alignof(double) == _Alignof(double complex));
}
#endif

void c11_6_2_5_26(void) // _Alignof(t) == _Alignof(qualifier t)
// + c11_6_2_5_27       // not necessarily if qualifier is _Atomic
{
  _Static_assert(_Alignof(char) == _Alignof(const char));
  _Static_assert(_Alignof(char) == _Alignof(volatile char));

  _Static_assert(_Alignof(int) == _Alignof(const int));
  _Static_assert(_Alignof(int) == _Alignof(volatile int));

  _Static_assert(_Alignof(struct basic_s) == _Alignof(const struct basic_s));
  _Static_assert(_Alignof(struct basic_s) == _Alignof(volatile struct basic_s));

  _Static_assert(_Alignof(struct nested_s) == _Alignof(const struct nested_s));
  _Static_assert(_Alignof(struct nested_s) == _Alignof(volatile struct nested_s));

  // we add restrict for pointers
  _Static_assert(_Alignof(char*) == _Alignof(const char*));
  _Static_assert(_Alignof(char*) == _Alignof(volatile char*));
  _Static_assert(_Alignof(char*) == _Alignof(char * restrict));

  // _Atomic does not have the same constraints.
}

void c11_6_2_5_28_1(void){
  _Static_assert(_Alignof(void*) == _Alignof(char*));
}

typedef int int_t ;
typedef struct basic_s basic_t ;
typedef union basic_u u_t ;
typedef enum E e_t ;

void c11_6_2_5_28_2(void)
// pointers to compatible types have the same alignment
{
  _Static_assert(_Alignof(int*) == _Alignof(int_t*));
  _Static_assert(_Alignof(struct basic_s*) == _Alignof(basic_t*));
  _Static_assert(_Alignof(union basic_u*) == _Alignof(u_t*));
  _Static_assert(_Alignof(enum E*) == _Alignof(e_t*));
  _Static_assert(_Alignof(enum E*) == _Alignof(int*));
}

void c11_6_2_5_28_3(void)
// pointers to struct types have the same alignment
{
  _Static_assert(_Alignof(struct basic_s*) == _Alignof(struct nested_s*));
}

void c11_6_2_5_28_4(void)
// pointers to union types have the same alignment
{
  _Static_assert(_Alignof(union basic_u*) == _Alignof(union nested_u*));
}

void c11_6_2_8_6(void)
// _Alignof(s-u-char) is the weakest
{
  // on our test architecture:
  _Static_assert(_Alignof(char) == 1);
  _Static_assert(_Alignof(unsigned char) == 1);
  _Static_assert(_Alignof(signed char) == 1);
}

typedef int function_type(void);

void c11_6_5_3_4_1(void){
#ifdef FAIL_FUNCTION /* undefined behavior: _Alignof(function type) */
  int a = _Alignof(function_type);
#endif
#ifdef FAIL_INCOMPLETE /* undefined behavior: _Alignof(incomplete type) */
  int a = _Alignof(struct X);
#endif
}

void c11_6_5_3_4_3(void)
// _Alignof(T) == _Alignof(T[N])
{
  _Static_assert(_Alignof(int) == _Alignof(int[10]));
  _Static_assert(_Alignof(float) == _Alignof(float[10]));
  _Static_assert(_Alignof(struct basic_s) == _Alignof(struct basic_s[10]));
  _Static_assert(_Alignof(struct nested_s) == _Alignof(struct nested_s[10]));
  _Static_assert(_Alignof(union basic_u) == _Alignof(union basic_u[10]));
  _Static_assert(_Alignof(union nested_u) == _Alignof(union nested_u[10]));
}

struct bitfield {
  unsigned sign:     1;
  unsigned exp:      8;
  unsigned mantissa: 23;
};

void c11_6_7_2_1(void)
// unspecified behavior: _Alignof(bitfield type)
{
  int x = _Alignof(struct bitfield);
}
