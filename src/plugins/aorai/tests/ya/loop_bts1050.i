/* run.config*
   OPT: -aorai-automata @PTEST_DIR@/@PTEST_NAME@.ya -load-module tests/Aorai_test.cmxs -aorai-acceptance -aorai-test-number @PTEST_NUMBER@ @PROVE_OPTIONS@
*/
void f(){};

void g(){};

int main(int c){
    if (c<0){ c = 0;}
    if (c>0){ c = 5;}
    while (c){
        f();
        g();
        c--;
    }
    return 0;
}
