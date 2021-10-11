/* run.config*
 EXIT: 1
   COMMENT: module also used by global_decl_loc.i
   MODULE: global_decl_loc
   OPT: @PTEST_DIR@/global_decl_loc.i
*/
extern int g;

int main(void) {
  int a = g;
  return a;
}
