/* run.config*
 EXIT: 1
   LIBS: global_decl_loc
   OPT: @PTEST_DIR@/global_decl_loc.i
*/

extern int g;

int main(void) {
  int a = g;
  return a;
}
