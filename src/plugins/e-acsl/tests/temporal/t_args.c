/* run.config, run.config_dev
   COMMENT: Check that command line parameters are properly tracked
*/

#include <stdio.h>

int main(int argc, const char **argv) {
  /*@assert \valid(&argc); */
  /*@assert \valid(argv); */
  /*@assert \valid(*argv); */
  return 0;
}
