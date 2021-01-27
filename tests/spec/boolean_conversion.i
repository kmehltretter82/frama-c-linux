/* run.config*
MODULE: @PTEST_DIR@/@PTEST_NAME@.cmxs
STDOPT:
*/
void __FC_assert(int c);
enum a {HA};
enum a b;
int main() {
  __FC_assert(!b);
}
