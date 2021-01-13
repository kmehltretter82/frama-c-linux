// Qualified Type-Array Size

#define N 0xFFu
#define P 128L
#define Q 0x8A

int a[N];
int b[P];
int c[Q];

typedef int Ta[N];
typedef int Tb[P];
typedef int Tc[Q];

int sa = sizeof(int[N]);
int sb = sizeof(int[P]);
int sc = sizeof(int[Q]);

/*@
  requires \valid(n + (0 .. sizeof(int[N])));
  requires \valid(p + (0 .. sizeof(int[P])));
  requires \valid(q + (0 .. sizeof(int[Q])));
  assigns \nothing;
 */
void f(int *n, int *p, int *q);
