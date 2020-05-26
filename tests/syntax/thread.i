/* run.config
   STDOPT: +"-machdep gcc_x86_32 -c11"
 */

__thread int a;
static __thread int b;
extern __thread int c;
_Thread_local int d;

int main() {
  a = 0;
  b = 0;
  c = 0;
  d = 0;
  return 0;
}
