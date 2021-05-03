/* run.config
   CMXS: @PTEST_NAME@
   EXECNOW: LOG @PTEST_NAME@_sav.res LOG @PTEST_NAME@_sav.err BIN @PTEST_NAME@.sav @frama-c@ -load-module %{dep:@PTEST_NAME@.cmxs} -eva @EVA_OPTIONS@ -out -input -deps -save @PTEST_NAME@.sav > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
   EXECNOW: LOG @PTEST_NAME@_sav.1.res LOG @PTEST_NAME@_sav.1.err BIN @PTEST_NAME@.1.sav @frama-c@ -save @PTEST_NAME@.1.sav -eva @EVA_OPTIONS@ -out -input -deps > @PTEST_NAME@_sav.1.res 2> @PTEST_NAME@_sav.1.err
   STDOPT: +"-load %{dep:@PTEST_NAME@.sav} -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
   CMD: @frama-c@ -load-module %{dep:@PTEST_NAME@.cmxs} @PTEST_FILE@ @OPTIONS@
   STDOPT: +"-load %{dep:@PTEST_NAME@.1.sav} -eva @EVA_OPTIONS@ -out -input -deps -journal-disable -print"
   STDOPT: +"-load %{dep:@PTEST_NAME@.1.sav} -eva @EVA_OPTIONS@ -out -input -deps -journal-disable"
   CMXS: status
   EXECNOW: LOG status_sav.res LOG status_sav.err BIN status.sav @frama-c@ -load-module %{dep:status.cmxs} -save status.sav > status_sav.res 2> status_sav.err
   STDOPT: +"-load-module %{dep:status.cmxs} -load %{dep:status.sav}"
   STDOPT: +"-load %{dep:status.sav}"
*/

int main() {
  int i, j;

  i = 10;
  /*@ assert (i == 10); */
  while(i--);
  j = 5;

  return 0;
}
