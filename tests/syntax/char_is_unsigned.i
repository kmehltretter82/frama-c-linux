/* run.config
   CMXS: machdep_char_unsigned
   OPT:-print -load-module %{dep:machdep_char_unsigned.cmxs} -machdep unsigned_char -then -constfold -rte
*/
char t[10];

void main() {
  int r = (t[0] == 'a');
  char c = 455;
}
