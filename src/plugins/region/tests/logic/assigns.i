
int B[64];

//@ assigns *p \from q, k ;
void byref(int** p, int* q, int k);
int caller_byref (int k) { int *a; byref(&a,B,k); return *a; }

//@ assigns \result \from q, k ;
int* result(int* q, int k);
int caller_result (int k) { int *a = result(B,k); return *a; }

//@ assigns \result;
int* imprecise(int* q, int k);
int* call_imprecise(int k) { return imprecise(B,k); }

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
