/*@
  region A: a1[0..n], a2[0..n];
  region B: b1[0..n], b2[0..n];
  assigns \nothing;
  */
void f(int *a1, int *a2, int *b1, int *b2, int n);

/*@ region d[..]; */
void job1_mix(int *d, int a1, int a2, int b1, int b2, int n)
{
  // D <- A | D <- A | D <- B | D <- B || 4 separated (D <- A,B)
  f( d + a1 , d + a2 , d + b1 , d + b2 , n );
}

/*@ region P: a[..], Q: b[..]; */
void job2_ok(int *a, int p1, int p2, int *b, int q1, int q2, int n)
{
  // P <- A | P <- A | Q <- B | Q <- B || 0 separated (P <- A, Q <- B)
  f( a + p1 , a + p2 , b + q1 , b + q2 , n );
}

/*@ region P: a[..], Q: b[..]; */
void job2_mix(int *a, int p1, int p2, int *b, int q1, int q2, int n)
{
  // P <- A | Q <- A | P <- B | Q <- B || 2 separated (P <- A,B ; Q <- A,B)
  f( a + p1 , b + q1 , a + p2 , b + q2 , n );
}

/*@ region P: a[..], Q: b[..], R: c[..]; */
void job3_ok(int *a, int *b, int *c, int p, int q, int n)
{
  // P <- A | Q <- A | R <- B | R <- B || 0 separated (P <- A, Q <- A, R <- B)
  f( a      , b      , c + p  , c + q  , n );
}

/*@ region P: a[..], Q: b[..], R: c[..]; */
void job3_mix(int *a, int *b, int *c, int p, int q, int n)
{
  // P <- A | R <- A | Q <- B | R <- B || 1 separated (P <- A, Q <- B ; R <- A,B)
  f( a      , c + p  , b      , c + q  , n );
}

/*@ region P: a[..], Q: b[..], R: c[..], S: d[..]; */
void job4_ok(int *a, int *b, int *c, int *d, int n)
{
  // P <- A | Q <- A | R <- B | S <- B || 0 separated (P <- A, Q <- B, R <- A, S <- B)
  f( a      , b      , c      , d      , n );
}

/*@ region P: a[..], c[..], Q: b[..], d[..]; */
void job4_mix(int *a, int *b, int *c, int *d, int n)
{
  // P <- A | Q <- A | P <- B | Q <- B || 2 separated (P <- A,B ; Q <- A,B)
  f( a      , b      , c      , d      , n );
}
