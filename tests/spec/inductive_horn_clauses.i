/*@ inductive incorrect_conclusion(integer x) {
      case ko: \forall integer x; incorrect_conclusion(x) ==> x != x + 1;
  }
*/

/*@ inductive negative_occurrence(integer x) {
  case ko: \forall integer x; !(negative_occurrence(x)) ==> negative_occurrence(x);
}
*/

/*@ inductive negative_through_let(integer x) {
  case ko:
    \forall integer x;
      \let p = \lambda integer x,y; negative_through_let(x+y);
      !p(x,2) ==> p(x,2);
}
*/

/*@ inductive ok_let(integer x) {
  case ok:
    \forall integer x,y;
      \let p = \lambda integer x, y; ok_let(x+y);
      p(x,0) ==> p(x,1);
  case base: ok_let(0);
}
*/
