/* run.config
   CMXS: @PTEST_NAME@
   EXECNOW: LOG basic_sav.res LOG basic_sav.err BIN basic.sav @frama-c@ -load-module %{dep:@PTEST_NAME@.cmxs} -eva @EVA_OPTIONS@ -out -input -deps ./@PTEST_DIR@/@PTEST_NAME@.i -save ./result/basic.sav > ./result/basic_sav.res 2> ./result/basic_sav.err
   EXECNOW: LOG basic_sav.1.res LOG basic_sav.1.err BIN basic.1.sav ./bin/toplevel.opt -save ./result/basic.1.sav @PTEST_DIR@/@PTEST_NAME@.i -eva @EVA_OPTIONS@ -out -input -deps > ./result/basic_sav.1.res 2> ./result/basic_sav.1.err
   STDOPT: +"-load ./result/basic.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
   CMD: @frama-c@ -load-module %{dep:@PTEST_NAME@.cmxs}
   STDOPT: +"-load ./result/basic.1.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable -print"
   STDOPT: +"-load ./result/basic.1.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
   CMXS: status
   EXECNOW: LOG status_sav.res LOG status_sav.err BIN status.sav @frama-c@ -load-module status -save ./result/status.sav @PTEST_DIR@/@PTEST_NAME@.i > ./result/status_sav.res 2> ./result/status_sav.err
   STDOPT: +"-load-module status -load ./result/status.sav"
   STDOPT: +"-load ./result/status.sav"
*/

int main() {
  int i, j;

  i = 10;
  /*@ assert (i == 10); */
  while(i--);
  j = 5;

  return 0;
}
