/*@
  predicate HasSubRange{A}(value_type* a, integer m,
                           value_type* b, integer n) =
    \exists size_type k; (0 <= k <= m-n) && IsEqual{A,A}(a+k, n, b);
*/