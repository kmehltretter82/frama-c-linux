/* run.config
 PLUGIN: @EVA_PLUGINS@ slicing
   EXECNOW: BIN sparecode.sav LOG sparecode_sav.res LOG sparecode_sav.err @frama-c@ -slicing-level 2 -slice-return main -eva-show-progress -save @PTEST_RESULT@/sparecode.sav %{dep:@PTEST_DIR@/sparecode.i} -then-on 'Slicing export' -print > @PTEST_RESULT@/sparecode_sav.res 2> @PTEST_RESULT@/sparecode_sav.err
   STDOPT: +"-load @PTEST_RESULT@/sparecode.sav"
*/
int G;
int f (int x, int y) {
  G = y;
  return x;
}

int main (void) {
  int a = 1;
  int b = 1;

  f (0, 0); /* this call is useless : should be removed */
  a = f (a, b); /* the result of this call is useless */
  a = f (G + 1, b);

  G = 0; /* don't use the G computed by f */

  return a;
}
