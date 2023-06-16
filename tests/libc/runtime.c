/* run.config*
   COMMENT: tests that the runtime can compile without errors (for PathCrawler, E-ACSL, ...)
   ENABLED_IF: %{bin-available:gcc}
   CMD: FRAMAC='@frama-c@' %{dep:@PTEST_DIR@/runtime.sh}
   OPT: %{dep:@FRAMAC_SHARE@/libc/__fc_runtime.c}
 */

int main() {
  return 0;
}
