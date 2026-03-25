/* run.config
  STDOPT:
  STDOPT: +"-unsafe-arrays"
  STDOPT: +"-no-warn-unaligned-pointer"
*/

struct S { int f[5]; };

//@ region *p ;
int default_ptr (int *p) { return *p; }

//@ region p[0..n-1] ;
int default_arr (int *p, int k, int n) { return p[k]; }

//@ region p;
int default_comp (struct S p, int k) { return p.f[k]; }

//@ region *p;
int default_pcomp (struct S *p, int k) { return p->f[k]; }

//@ region p[0..n-1];
int default_cast (char *p, int k, int n) { return *((int*)(p + k)); }

//@ region ((int*)p)[0..n-1];
int default_nocast (char *p, int k, int n) { return *((int*)p + k); }
