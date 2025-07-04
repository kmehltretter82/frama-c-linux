#include <stdlib.h>
#include <stdint.h>

volatile int nondet;

void int_constant_to_ptr(void){
  int32_t* p1 = (int32_t*) 4 ; // OK
  int32_t* p2 = (int32_t*) 8 ; // OK
  if (nondet) {
    int32_t* p3 = (int32_t*) 1 ; // KO
  }
}

void int_to_ptr(int32_t vunknown, int32_t vok, int32_t vko){
  // syntactic: all unknown
  // semantic: unknown, OK, KO, see caller below

  int32_t* p1 = (int32_t*) vunknown ;
  int32_t* p2 = (int32_t*) vok ;
  if (nondet) {
    int32_t *p3 = (int32_t *)vko;
  }
}

void int_to_ptr_caller(int32_t unknown){
  int_to_ptr(unknown, 4, 7);
}

void addrof_to_ptr(void){
  int8_t c ;
  _Alignas(4) int8_t c4 ;

  int32_t i ;
  _Alignas(8) int8_t i8 ;

  // all OK
  int8_t* pc1 = &c ;
  int8_t* pc2 = &c4 ;
  int8_t* pc3 = &i ;
  int8_t* pc4 = &i8 ;

  if (nondet) {int32_t* pi1 = &c ;} // unknown
  // all OK
  int32_t* pi2 = &c4 ;
  int32_t* pi3 = &i ;
  int32_t* pi4 = &i8 ;

  // all unknown
  if (nondet) {int64_t* pl1 = &c ;}
  if (nondet) {int64_t* pl2 = &c4 ;}
  if (nondet) {int64_t* pl3 = &i ;}
  int64_t* pl4 = &i8 ; // except this one: OK
}

void startof_to_ptr(void){
  int8_t c[4];
  _Alignas(4) int8_t c4[4];

  int32_t i[4] ;
  _Alignas(8) int8_t i8[4] ;

  // all OK
  int8_t* pc1 = c ;
  int8_t* pc2 = c4 ;
  int8_t* pc3 = i ;
  int8_t* pc4 = i8 ;

  if (nondet) {int32_t* pi1 = c ;} // unknown
  // all OK
  int32_t* pi2 = c4 ;
  int32_t* pi3 = i ;
  int32_t* pi4 = i8 ;

  // all unknown
  if (nondet) {int64_t* pl1 = c ;}
  if (nondet) {int64_t* pl2 = c4 ;}
  if (nondet) {int64_t* pl3 = i ;}
  int64_t* pl4 = i8 ; // except this one: OK
}

void ptr_to_ptr_syn(int16_t* p){
  uint8_t*  p1 = p ; // OK
  if (nondet) {uint32_t* p2 = p ;} // unknown
}

void ptr_to_ptr_sem(int8_t* cu, int8_t* c4){ // we expect c8 to be aligned on 4
  // syntactic: all unknown
  // semantic: unknown except for indicated lines

  if (nondet) {int16_t* i1 = cu ;}
  int16_t* i2 = c4 ; // semantic: OK

  if (nondet) {int32_t* i3 = cu ;}
  int32_t* i4 = c4 ; // semantic: OK

  if (nondet) {int64_t* i5 = cu ;}
  if (nondet) {int64_t* i6 = c4 ;}
}

void ptr_to_ptr_sem_caller(int8_t* p){
  int32_t x = 42;
  ptr_to_ptr_sem(p, (int8_t*) &x);

  _Alignas(int) int8_t y = '0';
  ptr_to_ptr_sem(p, (int8_t*) &y);
}

struct S{ int x, y, z; };
union U{ int x, y, z; };

void malloc_ok_for_any_type(void){
  // syntactically, RTE does not check that
  int8_t* p1 = malloc(128);
  int16_t* p2 = malloc(128);
  int32_t* p3 = malloc(128);
  int64_t* p4 = malloc(128);
  float* p5 = malloc(128);
  double* p6 = malloc(128);
  struct S * p7 = malloc(128);
  union U * p8 = malloc(128);
}

void must_not_trigger_failure(void){
  int *p = (int*) malloc_ok_for_any_type ;
}


volatile int32_t i32_nondet;

int main(void){
  int_constant_to_ptr();
  int_to_ptr_caller(i32_nondet);
  addrof_to_ptr();
  startof_to_ptr();
  int16_t x;
  ptr_to_ptr_syn(&x);
  int8_t a;
  ptr_to_ptr_sem_caller(&a);
}
