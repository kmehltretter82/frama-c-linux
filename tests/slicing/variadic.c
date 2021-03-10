/* run.config
    DEPS: ../../pdg/variadic.c
    STDOPT: +"-add-symbolic-path ../..:TESTS_DIR -slice-return f3 -no-slice-callers -journal-disable -then-on 'Slicing export' -print"
    STDOPT: +"-add-symbolic-path ../..:TESTS_DIR -slice-return f3 -no-slice-callers -journal-disable -variadic-no-translation -then-last -print"
    STDOPT: +"-add-symbolic-path ../..:TESTS_DIR -slice-return f3 -journal-disable -then-on 'Slicing export' -print"
    STDOPT: +"-add-symbolic-path ../..:TESTS_DIR -slice-return main -journal-disable -then-on 'Slicing export' -print"
    STDOPT: +"-add-symbolic-path ../..:TESTS_DIR -slice-return main -slicing-level 3  -journal-disable -then-on 'Slicing export' -print"
*/

#include "../../pdg/variadic.c"
