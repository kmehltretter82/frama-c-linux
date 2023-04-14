/* run.config
   LOG: @PTEST_NAME@.csv
   STDOPT: +" -eva-statistics-file ./@PTEST_NAME@.csv"
*/

/* This test only dump statistics in the default configuration
   to avoid oracle duplication. */

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
