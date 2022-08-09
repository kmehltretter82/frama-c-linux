/* run.config
   COMMENT: recursive logic functions
*/

/*
  STDOPT: +"-eva-unroll-recursive-calls 100"
*/

/*@ predicate even (integer n) =
      n == 0 ? \true :
      n > 0 ? ! even (n - 1) :
      ! even (n + 1);
*/

/*@ predicate even_and_not_negative (integer n) =
      n == 0 ? \true :
      n > 0 ? ! even (n - 1) :
      \false;
*/

/*@ logic integer f1(integer n) =
    n <= 0 ? 0 : f1(n - 1) + n; */

/*@ logic integer f2(integer n) =
    n < 0 ? 1 : f2(n - 1)*f2(n - 2)/f2(n - 3); */

/*@ logic integer g(integer n) = 0; */
/*@ logic integer f3(integer n) =
    n > 0 ? g(n)*f3(n - 1) - 5 : g(n + 1); */

/*@ logic integer f4(integer n) =
    n < 100 ? f4(n + 1) :
    n < 0x7fffffffffffffffL ? 0x7fffffffffffffffL :
    6; */

/*@ logic integer f5(integer n) =
  n >= 0 ? 0 : f5(n + 1) + n; */

int main(void) {
  /*@ assert even(10); @*/;
  /*@ assert even(-6); @*/;
  /*@ assert even_and_not_negative(10); */;
  /*@ assert f1(0) == 0; */;
  /*@ assert f1(1) == 1; */;
  /*@ assert f1(10) == 55; */;

  /*@ assert f2(7) == 1; */;

  /*@ assert f3(6) == -5; */;

  /*@ assert f4(9) > 0; */;

  /*@ assert f5(0) == 0; */

  /*@ assert (\let n = (0 == 0) ? 0x7fffffffffffffffL : -1; f5(n) == 0);*/
}
