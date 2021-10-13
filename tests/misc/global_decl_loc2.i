/* run.config*
 COMMENT: the script "global_decl_loc.ml" is also used by the test "global_decl_loc.i"
 SCRIPT: global_decl_loc
   OPT: @PTEST_DIR@/global_decl_loc.i
*/

extern int g;

int main(void) {
  int a = g;
  return a;
}
