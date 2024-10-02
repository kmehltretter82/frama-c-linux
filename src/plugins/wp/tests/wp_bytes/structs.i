struct X {
  char  c ;
  short s ;
  int   i ;
  int   a[5] ;
} ;

struct Y {
  char c ;
  struct X x ;
} ;

//@ assigns *y ;
void callee(struct Y* y);

/*@ requires \separated(u, y) ;
    assigns  *y ;
    ensures  *u == \old(*u) ;
*/
void caller(struct Y const* u, struct Y* y){
  callee(y) ;
}
