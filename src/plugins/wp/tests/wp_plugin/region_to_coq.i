/* run.config
   DONTRUN:
*/
/* run.config_qualif
   OPT: -wp-prover native:coq -wp-coq-script tests/wp_plugin/region_to_coq.script
*/

void copy(int* a, unsigned int n, int* b)
{
    /*@ loop invariant 0 <= i <= n ;
        loop assigns i, b[0..n-1]; */
    for(unsigned int i = 0; i < n; ++i)
        b[i] = a[i];
}
