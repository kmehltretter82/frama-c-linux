/* run.config*
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -load-module tests/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
 */
void main(void)
{
	//@ loop assigns i;
	for (int i=0; i<10; ++i)
		;
}
