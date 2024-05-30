/* run.config
  CMD: @frama-c@ @PTEST_OPTIONS@
  EXECNOW: BIN @PTEST_NAME@.sav LOG @PTEST_NAME@_sav.res LOG @PTEST_NAME@_sav.err @frama-c@ -save @PTEST_NAME@.sav @PTEST_FILE@ -eva @EVA_OPTIONS@ > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
  STDOPT: +"%{dep:inout_import_2.c} -eva -eva-load %{dep:@PTEST_NAME@.sav} @EVA_OPTIONS@  -deps -out -input"
*/

int a = 0;

void f2()
{
}
int f1()
{
  a = 1;
  return a;
}

void main()
{
  f1();
  f2();
}
