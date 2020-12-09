/* run.config
   OPT: -machdep x86_32 -rte -then -print
   OPT: -machdep x86_64 -rte -then -print
 */

int main(void) {
  signed long int lx, ly, lz;
  lz = lx * ly;
  return 0;
}
