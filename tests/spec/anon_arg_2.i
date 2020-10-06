/* run.config*
CMD: frama-c @FRAMA_C_PLUGINS_OPTIONS@ @OPTIONS@ %{dep:anon_arg_1.i} @PTEST_FILE@
OPT: -pp-annot -print -journal-disable -kernel-warn-key=annot-error=active -check
*/

/*@ requires \valid(p);
    assigns *p \from x;
    ensures \result == x && *p == x;
*/
int f(int* p, int x);

/*@ requires \valid(p);
    assigns *p;
    ensures *p == \result;
*/
int g(int*p, int);
