/* run.config
   NOFRAMAC: testing frama-c-script
   COMMENT: we must filter 'make:' output lines, since they differ when run by the CI (e.g. mention to jobserver)
   EXECNOW: LOG make-wrapper.res LOG make-wrapper.err cd @PTEST_DIR@ && FRAMAC=../../bin/frama-c ../../bin/frama-c-script make-wrapper --make-dir . -f make-for-make-wrapper.mk | sed -e "s:$PWD:PWD:g" | grep -v "^make.*" > result/make-wrapper.res 2> result/make-wrapper.err && rm -rf make-for-make-wrapper.parse make-for-make-wrapper.eva
*/

int defined(int a);

int specified(int a);

int external(int a);

int main() {
  int a = 42;
  a = defined(a);
  a = specified(a);
  a = external(a);
}
