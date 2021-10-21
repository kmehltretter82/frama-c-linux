/* run.config
  COMMENT: Compile RTL with debug and debug verbose informations
  STDOPT:#"-e-acsl-debug 1"
 */
/* run.config_dev
  MACRO: ROOT_EACSL_GCC_OPTS_EXT --rt-debug --rt-verbose --full-mtracking
  COMMENT: Filter the addresses of the output so that the test is deterministic.
  MACRO: ROOT_EACSL_EXEC_FILTER @SEDCMD@ -e "s|0x[0-9-]*|0x00000-00000-00000|g" | @SEDCMD@ -e "s|Offset: [0-9-]*|Offset: xxxx|g"
 */
int main() {
  return 0;
}
