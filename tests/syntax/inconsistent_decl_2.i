/* run.config
<<<<<<< HEAD
DONTRUN: main test is at inconsistent_decl.c
||||||| 754e522ceb
DONTRUN: main test is at tests/syntax/inconsistent_decl.c
=======
DONTRUN: main test is at @PTEST_DIR@/inconsistent_decl.c
>>>>>>> origin/master
*/

int f(double x);

int h() {
  int x = f(2.0);
  return x;
}
