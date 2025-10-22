/* Tests that builtins are not used for function with incompatible types. */

/* Integers instead of floating-point numbers. */
int pow (int a, int b) {
  int x = 1;
  //@ loop unroll 10;
  for (int i = 0; i < b; i++)
    x = x * a;
  return x;
}

/* Float instead of double. */
/*@ assigns \result \from f; */
float exp (float f);

int main(void) {
  int n = pow(2, 4);
  float f = exp(1.5f);
}
