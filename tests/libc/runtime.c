/* run.config*
   COMMENT: tests that the runtime can compile without errors (for PathCrawler, E-ACSL, ...)
   DEPS: ../../../share/libc/__fc_runtime.c
   CMD: gcc @OPTIONS@
   OPT: -D__FC_MACHDEP_X86_64 ../../../share/libc/__fc_runtime.c -Wno-attributes -std=c99 -o /dev/null @PTEST_FILE@
 */

int main() {
  return 0;
}
