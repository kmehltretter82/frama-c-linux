/* run.config

   MODULE: @PTEST_NAME@
   STDOPT: +"-generated-spec-mode donothing"
   STDOPT: +"-generated-spec-mode safe"
   STDOPT: +"-generated-spec-mode frama-c"
*/

/*@ axiomatic a {
  @ predicate P reads \nothing;
  @ predicate Q reads \nothing;
  @ predicate R reads \nothing;
  }*/


// Test combine exits
/*@ behavior A:
  @   exits P;
  @ behavior B:
  @   exits Q;
  @   exits R;
  @ complete behaviors;
  @*/
void f1(void);

// Test combine assigns
/*@ behavior A:
  @   assigns *a;
  @ behavior B:
  @   assigns *b;
  @   assigns *a \from c;
  @   assigns *a \from d;
  @   assigns *b \from c;
  @ behavior C:
  @   assigns *a, *b;
  @ complete behaviors;
  @*/
void f2(int* a, int *b, int c, int d);

// Test combine requires
/*@ behavior A:
  @   requires P;
  @   requires Q;
  @ behavior B:
  @   requires P;
  @   requires R;
  @   requires R;
  @ complete behaviors;
  @*/
void f3(void);

// Test combine frees/allocates
/*@ behavior A:
  @   allocates \result;
  @   allocates \old(a);
  @   frees b;
  @ behavior B:
  @   allocates \result;
  @   allocates \old(a);
  @   allocates \old(b);
  @   frees \nothing;
  @ behavior C:
  @   allocates \nothing;
  @   frees a, b;
  @ complete behaviors;
  @*/
int* f4(int* a, int* b);
