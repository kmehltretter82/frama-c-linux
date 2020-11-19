/* run.config*
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -aorai-test 1 -aorai-acceptance -load-module tests/Aorai_test.cmxs -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
*/

struct People{
	int Age;

	char Gender;

};

struct People nobody;

int myAge=0;

void increment(){
    nobody.Age++;
    myAge++;
}


int main() {
    nobody.Age=0;
    increment();
    return 0;
}
