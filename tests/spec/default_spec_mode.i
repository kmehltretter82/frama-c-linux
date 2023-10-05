/* run.config
   MODULE: @PTEST_NAME@
   STDOPT: +"-generated-spec-mode acsl"
   STDOPT: +"-generated-spec-mode safe"
   STDOPT: +"-generated-spec-mode frama-c"
   STDOPT: +"-generated-spec-mode skip"
   STDOPT: +"-generated-spec-custom exits:skip,assigns:frama-c,requires:safe,allocates:safe,terminates:acsl"
   EXIT: 1
   STDOPT: +"-generated-spec-custom wrong_clause:safe"
   STDOPT: +"-generated-spec-custom wrong_clause:"
*/

// empty spec prototype
void f1(void);

// empty spec function
void f2(){
  f1();
  return;
}

// Test for automatic assigns
//@ requires \true;
int f3(int* a);

// Has behavior by default
/*@ requires \true;
  @ assigns *b;
*/
int f4(int* b){
  return f3(b);
}
