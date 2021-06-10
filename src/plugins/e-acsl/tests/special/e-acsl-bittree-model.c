/* run.config_ci, run.config_dev
  COMMENT: Compile RTL with bittree memory model
  STDOPT:#"-e-acsl-full-mtracking"
  MACRO: ROOT_EACSL_GCC_OPTS_EXT --full-mtracking --memory-model bittree
 */
int main() {
  return 0;
}
