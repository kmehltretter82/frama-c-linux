/* run.config
   CMXS: @PTEST_NAME@
   EXECNOW: LOG basic_sav.res LOG basic_sav.err BIN basic.sav @frama-c@ -load-module %{dep:@PTEST_NAME@.cmxs} -eva @EVA_OPTIONS@ -out -input -deps @PTEST_NAME@.i -save basic.sav > basic_sav.res 2> basic_sav.err
   EXECNOW: LOG basic_sav.1.res LOG basic_sav.1.err BIN basic.1.sav ./bin/toplevel.opt -save basic.1.sav @PTEST_NAME@.i -eva @EVA_OPTIONS@ -out -input -deps > basic_sav.1.res 2> basic_sav.1.err
   STDOPT: +"-load basic.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
   CMD: @frama-c@ -load-module %{dep:@PTEST_NAME@.cmxs}
   STDOPT: +"-load basic.1.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable -print"
   STDOPT: +"-load basic.1.sav -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
   CMXS: status
   EXECNOW: LOG status_sav.res LOG status_sav.err BIN status.sav @frama-c@ -load-module status -save status.sav @PTEST_NAME@.i > status_sav.res 2> status_sav.err
   STDOPT: +"-load-module status -load status.sav"
   STDOPT: +"-load status.sav"
*/

int main() {
  int i, j;

  i = 10;
  /*@ assert (i == 10); */
  while(i--);
  j = 5;

  return 0;
}
