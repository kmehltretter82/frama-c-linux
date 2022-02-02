/* run.config*
 EXIT: 1
   STDOPT:
*/

// invalid field with function type, parsing should fail
struct {
  void f(int);
} s;

// negative-width bitfields, parsing should fail
struct neg_bf
{
  int a:(-1); // invalid
  int b:(-2147483647-1); // invalid
  int d:(-0); // valid
};
