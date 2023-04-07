/* run.config*
   LOG: @PTEST_NAME@.stats
   STDOPT: +" -eva-statistics-file ./@PTEST_NAME@.stats"
*/

void g(int i) {}

void f(int n) {
  for (int i = 0 ; i < n ; i++) {
    g(i);
  }
}

int main(int n) {
  f(n);
  f(n-1);
}
