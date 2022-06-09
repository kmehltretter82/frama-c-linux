/* run.config*
   OPT: -aorai-automata %{dep:@PTEST_DIR@/@PTEST_NAME@.ya} -aorai-acceptance -aorai-test-id @PTEST_NUMBER@@PTEST_CONFIG@ @PROVE_OPTIONS@
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
