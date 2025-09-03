/* run.config
  STDOPT: -acsl-importer-debug 2 -acsl-importer-msg-key trace-ensures-and-exits -acsl-addon-ensures-and-exits -acsl-keep-unused-symbols -acsl-import %{dep:./@PTEST_NAME@.acsl} -then -print -then -print -ocode ./ocode_@PTEST_NUMBER@_@PTEST_NAME@.i -then -no-print ./ocode_@PTEST_NUMBER@_@PTEST_NAME@.i
 */

//@ \acsl_importer::ensures_and_exits q: c==0? \exit_status==1 : \result==1;
int may_exits(int c);
