/* run.config*
   FILTER: sed "s:/[^ ]*[/]cpp-command\.[^ ]*\.i:TMPDIR/FILE.i:g; s:$PWD/::g; s: -m32::"
   OPT: -machdep x86_32 -cpp-frama-c-compliant -cpp-command "echo [\$(basename '%1') \$(basename '%1') \$(basename '%i') \$(basename '%input')] ['%2' '%2' '%o' '%output'] ['%args']"
   OPT: -machdep x86_32 -cpp-frama-c-compliant -cpp-command "echo %%1 = \$(basename '%1') %%2 = '%2' %%args = '%args'"
   OPT: -machdep x86_32 -cpp-frama-c-compliant -cpp-command "printf \"%s\n\" \"using \\% has no effect : \$(basename \"\%input\")\""
   OPT: -machdep x86_32 -cpp-frama-c-compliant -cpp-command "echo %var is not an interpreted placeholder"
   OPT: -machdep x86_32 -print-cpp-commands
   OPT: -cpp-extra-args-per-file=@PTEST_FILE@:"-DPF=\\\"cp%02d_3f\\\"" -no-autoload-plugins @PTEST_FILE@ -print
   */

#include <stdio.h>
void printer(int i, float f) {
  printf(PF, i, f);
}

int main() {
  printer(1, 1.0);
}
