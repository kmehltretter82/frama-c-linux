int i ;
int const c ;

//@ assigns i ;
void accept_non_const(void);

//@ assigns c ;
void refuse_const(void);

const int a[2];

//@ assigns a[0] ;
void refuse_const_array(void);

//@ assigns { i, c };
void refuse_const_in_set(void);

struct X { int const f; };
struct Y { struct X a[10] ; };
struct Y y ;

//@ assigns y.a[4].f ;
void refuse_const_field(void);

//@ assigns (*ptr).a[4].f ;
void refuse_field_via_pointer(struct Y * ptr);

// Acceptable const assigns:

//@ assigns *ptr ;
void accept_const_via_pointer(int const * ptr);
