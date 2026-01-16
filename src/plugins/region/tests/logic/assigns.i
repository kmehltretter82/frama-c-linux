
int B[64];

//@ assigns *p \from q, k ;
void byref(int** p, int* q, int k);
int call_byref (int k) { int *a; byref(&a,B,k); return *a; }

//@ assigns *p ;
void imprecise(int** p, int* q, int k);
int call_imprecise (int k) { int *a; imprecise(&a,B,k); return *a; }

//@ assigns \result \from q, k ;
int* result(int* q, int k);
int caller_result (int k) { int *a = result(B,k); return *a; }

//@ assigns \result ;
int* imprecise_result(int* q, int k);
int* call_imprecise_result(int k) { return imprecise_result(B,k); }

//@ assigns \result \from \nothing ;
int* nothing(void);
int* call_nothing(int k) { return nothing(); }

struct S { int *f; int *g[4]; };

//@ assigns p->f \from q;
void set_field(struct S *p, int *q);
void call_field(void) { struct S s; int a; set_field(&s,&a); return; }

//@ assigns p->g[..] \from q;
void set_range(struct S *p, int *q);
void call_range(void) { struct S s; int a; set_range(&s,&a); return; }

//@ assigns *p \from *q;
void copy(struct S *p, struct S *q);
void call_copy(void) { struct S a,b; copy(&a,&b); return; }
