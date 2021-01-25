/* run.config*
   OPT: -simplify-cfg -keep-switch -eva @EVA_OPTIONS@
   OPT: -simplify-cfg -eva @EVA_OPTIONS@
*/

int main(int x, int y) {
  int z = 0;
  char c = 'c';
  switch (x) {
  case 0: z=(int)c;
  default: z++;
  }
  return z;
}
