/* run.config*
   COMMENT: tests that the runtime can compile without errors (for PathCrawler, E-ACSL, ...)
   COMMENT: dependency to FRAMA-C share directory is implicit
   CMD: gcc @PTEST_OPTIONS@
   OPT: -D__FC_MACHDEP_X86_64 ../../../../install/default/share/frama-c/share/libc/__fc_runtime.c -Wno-attributes -std=c99 -o /dev/null @PTEST_FILE@
 */

int main() {
  return 0;
}
