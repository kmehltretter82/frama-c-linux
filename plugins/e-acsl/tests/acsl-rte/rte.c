/* run.config
 * COMMENT: Check that the RTE guards are generated at the right place.
 * STDOPT: #"-e-acsl-O-rte-initialized -warn-invalid-pointer -warn-signed-downcast -warn-unsigned-downcast"
*/
/* run.config_dev
 * MACRO: ROOT_EACSL_GCC_FC_EXTRA_EXT -e-acsl-O-rte-initialized -warn-invalid-pointer -warn-signed-downcast -warn-unsigned-downcast
*/

#include <limits.h>
#include <stdlib.h>
#include <sys/types.h>

struct s {
  int *b;
};

/*@ ensures
    \let delta = 1;
    \let avg_real = (a+b)/2;
    avg_real - delta < \result < avg_real + delta; */
double avg(double a, double b) {
  return (a + b) / 2;
}

// pathological case for issue #146
void g(int a, int *b) {
  //@ assert a / b[1] == 0;
}

int n = 1;

/*@ ensures *\result == 1; */ // pathological case for item #202
int *func_ptr() {
  return &n;
}

/*@ ensures \result == 1; */ // pathological case for item #136
int func() {
  return 1;
}

/*@ logic double f2(double x) = (double)(1/x); */

/*@
  requires 1 % a == 1;
  ensures 1 % b == 1;

  behavior bhvr:
    assumes 1 % c == 1;
    requires 1 % d == 1;
    requires (1 % f == 1) || (1 % g == 1);
    requires (1 % h == 1) && (1 % i == 1);
    requires \let var = 1; var % j == 1;
    requires \forall integer var; 0 <= var < k ==> var % k == var;
    requires \exists integer var; 0 <= var < l && var % l == var;
    ensures 1 % e == 1;
*/
void test(int a, int b, int c, int d, int e, int f, int g, int h, int i, int j,
          int k, int l) {}

void simple_loop() {
  int sum = 0;
  int x = 11;
  /*@ loop invariant 0 <= i / x; */
  for (int i = 0; i < 10; i++) {
    sum += i;
    x -= 1;
  }
}

void nested_loop() {
  int a[10];

  for (int i = 0; i < 10; i++) {
    a[i] = i;
  }

  int k;
  /*@ loop invariant 1 <= k <= 10;
    @ loop invariant \forall integer i; 1 <= i < k ==> a[i] / i == 1; */
  for (k = 1; k < 10; k++) {
    a[k] = a[k] / 1;
  }
}

// test function for downcast RTE guard
void dtests() {
  char x = 42;
  char y = 59;
  char z = 101;
  unsigned char uc = 101;
  unsigned int ux = 101;
  unsigned int uy = 100;
  unsigned int uz = 1;
  int i = 101;
  unsigned short j = 101;

  /*@ assert z == (char) (x + y); */
  /*@ assert uc == (unsigned char) (x + y); */
  /*@ assert uc == (unsigned char) i; */
  /*@ assert i == (int) (uy + uz); */
  /*@ assert ux == (unsigned int) (uy + uz); */
  /*@ assert j == (unsigned short) (uy + uz); */

  int *ptr_y = &i;
  // /*@ assert (short)ptr_y == (short)&i; */ // fail because of a pointer downcast assertion
  /*@ assert \aligned(ptr_y,alignof(int)); */

  char c = 'a';
  // fail because of an unsigned downcast assertion
  // /*@ assert \aligned(&c, ULONG_MAX + 1); */ // pathological case of issue #214

  float fx = 3.0;
  /*@ assert (int)fx == 3; */
}

int main(void) {
  int y = 2;
  long z = 2L;
  int w = 12;

  /*@ assert 4 / 2 == 2; */               // trivial case for division by zero
  /*@ assert (1 == 1) || (1 / y) < 2 ; */ // pathologic case for item #287
  /*@ assert 4 / y == 2 || 1 / w > 0; */
  /*@ assert 4 / (12 + 3 - 6) < 2; */

  /*@ assert 1 + ((z+1) / (y-123456789123456789)) == 1; */

  /*@ assert \forall integer i,j; 0 <= i < 5 / y && 4 <= j < 100 % y ==> j + i < 10; */

  double d = 2.0;
  /*@ assert f2(d) > 0; */

  test(2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13);

  simple_loop();
  nested_loop();

  char *x = malloc(sizeof(char));
  *x = 'x';
  unsigned int v = 1;
  /*@ assert \aligned(x,v); */
  /*@ assert \aligned(x,alignof(char)); */

  /*@ assert 12 / (v / (y / z)) > 0; */

  int c = 98;
  int tv = 1;
  int fv = 2;
  int ffv = 1;
  /*@ assert 12 / c ? (1 / tv) < 3 : (1 / ((fv / ffv) - 1)) > 0; */

  int *n = &y;
  /*@ assert 12 / *n > 0; */

  int t_1[3] = {1, 2, 3};
  int t_2[3] = {1, 6, 3};
  /*@ assert t_1 != t_2; */

  int *ptr_t = t_1;
  /*@ assert t_1 == (int[])ptr_t; */

  int m[3][2] = {{1, 2}, {3, 4}, {5, 6}};
  /*@ assert m == m; */

  long i = 1;
  /*@ assert (float)i == t_1[(int)0.1]; */

  int ***p = malloc(sizeof(int **));
  *p = malloc(sizeof(int *));
  **p = malloc(sizeof(int));
  ***p = 23;
  /*@ assert ***p / i == 23; */

  struct s struct_s;
  struct_s.b = &c;
  /*@ assert !\initialized(struct_s.b + (0..1)); */ // pathological case for item #96

  func();
  func_ptr();

  dtests();

  return 0;
}
