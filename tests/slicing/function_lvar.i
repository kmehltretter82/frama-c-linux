/* run.config*
OPT: -slice-pragma main
*/
int g(int x) { return x; }

int main() {
  /*@ assert &g == &g; */
  /*@ slice pragma stmt; */
  g(0);
}
