/* run.config
   OPT: -metrics-used-files %{dep:@PTEST_DIR@/@PTEST_NAME@1.i} %{dep:@PTEST_DIR@/@PTEST_NAME@2.i} %{dep:@PTEST_DIR@/@PTEST_NAME@3.i} %{dep:@PTEST_DIR@/@PTEST_NAME@4.i} %{dep:@PTEST_DIR@/@PTEST_NAME@5.i} %{dep:@PTEST_DIR@/@PTEST_NAME@6.i} %{dep:@PTEST_DIR@/@PTEST_NAME@7.i} %{dep:@PTEST_DIR@/@PTEST_NAME@8.i} %{dep:@PTEST_DIR@/@PTEST_NAME@9.c} @PTEST_DIR@/@PTEST_NAME@1.h @PTEST_DIR@/@PTEST_NAME@2.h
   OPT: -metrics-used-files -main g %{dep:@PTEST_DIR@/@PTEST_NAME@1.i} %{dep:@PTEST_DIR@/@PTEST_NAME@2.i} %{dep:@PTEST_DIR@/@PTEST_NAME@3.i} %{dep:@PTEST_DIR@/@PTEST_NAME@4.i} %{dep:@PTEST_DIR@/@PTEST_NAME@5.i} %{dep:@PTEST_DIR@/@PTEST_NAME@6.i} %{dep:@PTEST_DIR@/@PTEST_NAME@7.i} %{dep:@PTEST_DIR@/@PTEST_NAME@8.i} %{dep:@PTEST_DIR@/@PTEST_NAME@9.c} @PTEST_DIR@/@PTEST_NAME@1.h @PTEST_DIR@/@PTEST_NAME@2.h
*/

int h(void);

extern int glob;

void indirect(void);

void indirect_unused(void);

int k(void);

int main() {
  void (*fp)() = indirect;
  fp();
  return h() + glob + k();
}
