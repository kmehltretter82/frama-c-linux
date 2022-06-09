/* run.config*
   OPT: -aorai-automata %{dep:@PTEST_DIR@/@PTEST_NAME@.ya} -aorai-acceptance -aorai-test-id @PTEST_NUMBER@@PTEST_CONFIG@ @PROVE_OPTIONS@
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
