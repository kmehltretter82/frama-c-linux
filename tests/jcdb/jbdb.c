/* run.config
OPT: -json-compilation-database @PTEST_DIR@/build_commands.json -print
*/

int f2 () {
  return RETCODE; // defined in build_commands.json
}
