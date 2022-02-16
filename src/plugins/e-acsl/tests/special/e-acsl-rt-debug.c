/* run.config
  COMMENT: Compile RTL with debug and debug verbose informations
  STDOPT:#"-e-acsl-debug 1"
 */
/* run.config_dev
  MACRO: ROOT_EACSL_GCC_OPTS_EXT --rt-debug --rt-verbose --full-mtracking
  COMMENT: Filter the addresses of the output so that the test is deterministic.
  MACRO: ROOT_EACSL_EXEC_FILTER @SEDCMD@ -e s_0x[0-9a-f-]*_0x0000-0000-0000_g | @SEDCMD@ -e s_Offset:\s[0-9-]*_Offset:xxxxx_g | @SEDCMD@ -e s/[0-9]*\skB/xxxkB/g
 */
int main() {
  return 0;
}
