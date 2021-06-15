/* run.config
 PLUGIN: @EVA_PLUGINS@ constant_propagation
   EXECNOW: BIN multi_project.sav LOG multi_project_sav.res LOG multi_project_sav.err @frama-c@ -save ./tests/saveload/result/multi_project.sav @EVA_OPTIONS@ -semantic-const-folding @PTEST_DIR@/@PTEST_NAME@.i > tests/saveload/result/multi_project_sav.res 2> tests/saveload/result/multi_project_sav.err
   STDOPT: +"-load ./tests/saveload/result/multi_project.sav"
 MODULE: @PTEST_NAME@
   OPT: -eva @EVA_OPTIONS@
*/
int f(int x) {
  return x + x;
}

int main() {
  int x = 2;
  int y = f(x);
  /*@ assert y == 4; */
  return x * y;
}
