/* run.config
   COMMENT: from project https://gitlab.inria.fr/why3/why3
   COMMENT: from examples/in_progress/vacid_0_union_find.mlw
   COMMENT: No executable code is generated because of logic arrays.
   STDOPT: +"-eva-unroll-recursive-calls 5"
*/

/*@

logic integer size(int link[], int dist[], int num) = \length(link);

predicate inv(int link[], int dist[], int num) =
    \let s = \length(link);
    \length(dist) == s
 && (\forall integer i; 0 <= i < s ==> 0 <= link[i] < s)
 && (\forall integer i; 0 <= i < s ==>
        (dist[i] == 0 && link[i] == i)
     || (dist[i] > 0 && dist[link[i]] < dist[i]));

inductive repr(int link[], int dist[], int num, integer x, integer r) {
  case Repr_root:
    \forall int link[], dist[], num, integer x;
      inv(link, dist, num)
      && 0 <= x < size(link, dist, num)
      && link[x] == x
      ==> repr(link, dist, num, x, x);

  case Repr_link:
    \forall int link[], dist[], num, integer x, integer r;
      inv(link, dist, num)
      && 0 <= x < size(link, dist, num)
      && repr(link, dist, num, link[x], r)
      ==> repr(link, dist, num, x, r);
  }
*/

int arr[] = {1, 2, 3};

int main() {
  //@ assert repr(arr, arr, (int)1, 2, 3);
  return 0;
}
