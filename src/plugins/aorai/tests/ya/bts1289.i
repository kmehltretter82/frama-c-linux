/* run.config*
   OPT: -aorai-automata %{dep:@PTEST_DIR@/@PTEST_NAME@.ya} -aorai-test-id @PTEST_NUMBER@@PTEST_CONFIG@ @PROVE_OPTIONS@
   OPT: -aorai-automata %{dep:@PTEST_DIR@/@PTEST_NAME@-2.ya} -aorai-test-id @PTEST_NUMBER@@PTEST_CONFIG@ @PROVE_OPTIONS@
 */

void a(void) {}

void main(void)
{
	//@ loop assigns i;
	for (int i=0; i<10; ++i)
		a();
}
