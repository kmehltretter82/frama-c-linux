/* run.config
   OPT: -wp-model typed
   OPT: -wp-model bytes
*/

/* run.config_qualif
   DONTRUN:
*/

/*@
  ensures \result == i - j;
  assigns \nothing;
  */
int f (int *a, int i, int j)
{
  int *p = a + i ;
  int *q = a + j ;
  /*@ probe DIFF: p - q; */
  return p - q ;
}
