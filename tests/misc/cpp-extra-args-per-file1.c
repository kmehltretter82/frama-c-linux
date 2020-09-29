/* run.config
   OPT: -cpp-extra-args="-DGLOBAL" -cpp-extra-args-per-file @PTEST_DIR@/cpp-extra-args-per-file1.c:'-DFILE1 -DMACRO_WITH_QUOTES="\"hello world"\"',@PTEST_DIR@/cpp-extra-args-per-file2.c:"-DFILE2" -print -then %{dep:cpp-extra-args-per-file2.c} -no-print
 */

#ifndef GLOBAL
#error GLOBAL must be defined
#endif

#ifndef FILE1
#error FILE1 must be defined
#endif

#ifdef FILE2
#error FILE2 must NOT be defined
#endif

int main() {
  char *a = MACRO_WITH_QUOTES;
  return 0;
}
