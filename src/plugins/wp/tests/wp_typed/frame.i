struct { int f; int *ptr; } comp[20] ;

int *Q ;

//@ requires 0 <= k < 20 ;
void compound(int k) {
  int m = 1;
  Q = &m ; // alias taken on m
  *comp[k].ptr = 4 ;
  //@ assert SEP: \separated(comp[k].ptr,&m);
  //@ assert RES: m == 1;
}

// NOTE:
// if we require \valid(comp[k].ptr) the goal is provable without frame conditions
// since it can not be aliased with 'm' at PRE, which is not (yet) valid.
