/* run.config_qualif
   DONTRUN:
*/

//@ predicate P(integer x);

struct S {
  int f;
  int g[4];
};

/*@
  ensures F: P( \result.f );
  ensures G: P( \result.g[k] );
 */
struct S load(struct S *x, int k)
{
  return *x;
}
