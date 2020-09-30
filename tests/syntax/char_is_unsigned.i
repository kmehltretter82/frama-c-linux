/* run.config
   MODULE: machdep_char_unsigned.cmxs
   OPT:-print -machdep unsigned_char -then -constfold -rte
*/
char t[10];

void main() {
  int r = (t[0] == 'a');
  char c = 455;
}
