typedef unsigned char      uint8 ;

int x ;

void addr_glob(void){
  uint8 buffer[sizeof(int*)] ;
  *((int**) buffer) = &x ;

  int* r = *((int**) buffer) ;
  //@ check r == &x ;
}

void addr_formal(int x){
  uint8 buffer[sizeof(int*)] ;
  *((int**) buffer) = &x ;
  int* r = *((int**) buffer) ;

  //@ check r == &x ;
}

void addr_local_ok(void){
  int x = 0;

  uint8 buffer[sizeof(int*)] ;
  *((int**) buffer) = &x ;

  int* r = *((int**) buffer) ;
  //@ check P: r == &x ;
}

void addr_local_ko(void){
  uint8 buffer[sizeof(int*)] ;

  {
    int x ;
    *((int**) buffer) = &x ;
  }

  int* r = *((int**) buffer) ;
  //@ check r == &x ;
}

//@ requires \valid(f);
void pointer_param(int *f){
  uint8 buffer[sizeof(int*)] ;
  *((int**) buffer) = f ;

  int* r = *((int**) buffer) ;
  //@ check r == f ;
}
