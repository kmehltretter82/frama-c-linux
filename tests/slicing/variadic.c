/* run.config
    STDOPT: +"-slice-return f3 -no-slice-callers -then-on 'Slicing export' -print"
    STDOPT: +"-slice-return f3 -no-slice-callers -variadic-no-translation -then-last -print"
    STDOPT: +"-slice-return f3 -then-on 'Slicing export' -print"
    STDOPT: +"-slice-return main -then-on 'Slicing export' -print"
    STDOPT: +"-slice-return main -slicing-level 3  -then-on 'Slicing export' -print"
*/

#include "../pdg/variadic.c"
