//@ region *p ;
int default_ptr (int *p) { return *p; }

//@ region p[0..n-1] ;
int default_arr (int *p, int k, int n) { return p[k]; }

//@ region *p , \nullable ;
int nullable_ptr (int *p) { return *p; }

//@ region p[0..n-1] , \nullable ;
int nullable_arr (int *p, int k, int n) { return p[k]; }
