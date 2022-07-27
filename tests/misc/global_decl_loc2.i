/* run.config*
 COMMENT: with dune, the LIBS directive must be replaced by a MODULE directive (see also ./test_config file)

 MODULE: global_decl_loc
   OPT: %{dep:./global_decl_loc.i}
*/
extern int g;

int main(void) {
  int a = g;
  return a;
}
