/* run.config_ci, run.config_dev
  COMMENT: Compile RTL with segment memory model
  STDOPT:#"-e-acsl-full-mtracking"
  MACRO: ROOT_EACSL_GCC_OPTS_EXT --full-mtracking --memory-model segment
 */
int main() {
  return 0;
}
