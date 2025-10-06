/* run.config
OPT: -kernel-warn-key parser:decimal-float=warning
*/
int main() {
  double ok_max = 1e308;
  double too_big = 1e309;
  double ok_min_norm = 1e-308;
  double ok_min_denorm = 5e-324;
  double too_small = 1e-325;
  double dos = 1e-40000000 ;
  return 0 ;
}
