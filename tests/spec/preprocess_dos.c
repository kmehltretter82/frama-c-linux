/* run.config*
OPT: -cpp-command="@PTEST_DIR@/@PTEST_NAME@.sh %i %o" -cpp-frama-c-compliant -print
*/

int main() {
    int a = 0;
    /*@
        assert a == 0;
    */
    return a;
}
