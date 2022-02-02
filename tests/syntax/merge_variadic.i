/* run.config
<<<<<<< HEAD
OPT: %{dep:@PTEST_NAME@_aux.i} -print
||||||| 754e522ceb
OPT: @PTEST_DIR@/@PTEST_NAME@_aux.i -print
=======
PLUGIN: variadic
  OPT: @PTEST_DIR@/@PTEST_NAME@_aux.i -print
>>>>>>> origin/master
*/
int open (const char* file, int flags, int mode) {
  return -1;
}
/*@ assigns \result \from x; */
int foo (int x, int y);
