/* run.config*
 COMMENT: todo in the future: removes the EXECNOW command and modifies the MODULE directive in order to reuse "global_decl_loc"
 COMMENT: the script "global_decl_loc.ml" is also used by the test "global_decl_loc.i"
 EXECNOW: BIN global_decl_loc2.ml cp @PTEST_DIR@/global_decl_loc.ml @PTEST_RESULT@/global_decl_loc2.ml > @DEV_NULL@ 2> @DEV_NULL@
 MODULE: result/global_decl_loc2
   OPT: @PTEST_DIR@/global_decl_loc.i
*/
extern int g;

int main(void) {
  int a = g;
  return a;
}
