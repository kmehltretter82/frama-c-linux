/* run.config
  CMD: @frama-c@ @PTEST_OPTIONS@
  EXECNOW: BIN @PTEST_NAME@.sav LOG @PTEST_NAME@_sav.res LOG @PTEST_NAME@_sav.err @frama-c@ -save @PTEST_NAME@.sav @PTEST_FILE@ -eva -eva-msg-key=memexec,widening -eva-save-widenings -eva-reuse-widenings @EVA_OPTIONS@ > @PTEST_NAME@_sav.res 2> @PTEST_NAME@_sav.err
  STDOPT: +"%{dep:loop_reuse_2.c} -eva -eva-load %{dep:@PTEST_NAME@.sav} -eva-msg-key=memexec,widening -eva-save-widenings -eva-reuse-widenings @EVA_OPTIONS@"
*/
int a;

void loop()
{
    for (int i = 0; i < 10; i++)
    {
        a++;
    }
}

int main()
{
    loop();
}