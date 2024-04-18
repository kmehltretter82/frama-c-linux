/* run.config*
OPT: -slice-pragma main -then-last -print
*/
int g(int x) { return x; }

int main() {
  /*@ assert &g == &g; */
  /*@ slice_preserve_stmt; */
  g(0);
}
