/* run.config*
   STDOPT: +"-eva-auto-loop-unroll 32"
*/

/* Tests the evaluation and reduction by ACSL predicate on strings. */

#include "__fc_string_axiomatic.h"

volatile char nondet;

struct anything {
  int *ptr;
  double d;
  char c;
};

/*@ assigns \result \from p; */
char* garbled_mix(char *p);

/* Tests the reduction by ACSL predicate "valid_string" and "valid_read_string"
   from the Frama-C libc. */
void reduce_by_valid_string (void) {
  char s1[] = "hello\000 world!";
  char s2[] = "hello world!";
  const char s_const[] = "const char array";
  char s_zero[32] = {0};
  char s_uninit[32];

  char s_partially_initialized[32]; // valid only between 10 and 25.
  for (int i = 10; i < 25; i++) {
    s_partially_initialized[i] = 'i';
  }
  s_partially_initialized[25] = '\0';

  char s_invalid[32]; // Invalid as no terminating \0
  for (int i = 0; i < 32; i++){
    s_invalid[i] = 'a';
  }

  char s_partially_valid[32]; // valid up to offset 16.
  for (int i = 0; i < 32; i++){
    s_partially_valid[i] = 'o';
  }
  s_partially_valid[8] = '\0';
  s_partially_valid[16] = '\0';

  char s_imprecise[32]; // char array of imprecise values
  for (int i = 0; i < 32; i++){
    s_imprecise[i] = nondet;
  }

  char s_unknown[32]; // char array of imprecise values that may be uninitialized
  for (int i = 0; i < 32; i++) {
    if (nondet) s_unknown[i] = nondet;
  }

  int x;
  struct anything anything;
  anything.ptr = &x;
  anything.d = (double)nondet;
  anything.c = nondet;

  // Pointer p that can point to any of the strings above.
  char *p;
  switch (nondet) {
    case 0: p = "hello\000 world"; break;
    case 1: p = "hello world"; break;
    case 2: p = s1; break;
    case 3: p = s2; break;
    case 4: p = s_const; break;
    case 5: p = s_zero; break;
    case 6: p = s_uninit; break;
    case 7: p = s_partially_initialized; break;
    case 8: p = s_partially_valid; break;
    case 9: p = s_imprecise; break;
    case 10: p = s_unknown; break;
    case 11: p = (char *)&anything; break;
    default: p = NULL;
  }

  // Test with a zero offset for all bases.

  if (nondet) {
    //@ assert valid_string(p);
    Frama_C_show_each_valid_string_zero_offset(p);
  }

  if (nondet) {
    //@ assert valid_read_string(p);
    Frama_C_show_each_valid_read_string_zero_offset(p);
  }

  if (nondet) {
    //@ assert !valid_string(p);
    Frama_C_show_each_invalid_string_zero_offset(p);
  }

  if (nondet) {
    //@ assert !valid_read_string(p);
    Frama_C_show_each_invalid_read_string_zero_offset(p);
  }

  // Test with a precise non-zero non-singleton offset.
  int offset = nondet ? 5 : (nondet ? 10 : 20);
  p = p + offset;

  if (nondet) {
    //@ assert valid_string(p);
    Frama_C_show_each_valid_string_precise_offset(p);
  }

  if (nondet) {
    //@ assert valid_read_string(p);
    Frama_C_show_each_valid_read_string_precise_offset(p);
  }

  if (nondet) {
    //@ assert !valid_string(p);
    Frama_C_show_each_invalid_string_precise_offset(p);
  }

  if (nondet) {
    //@ assert !valid_read_string(p);
    Frama_C_show_each_invalid_read_string_precise_offset(p);
  }

  // Test with a very imprecise offset.
  p = p + nondet;

  if (nondet) {
    //@ assert valid_string(p);
    Frama_C_show_each_valid_string_imprecise_offset(p);
  }

  if (nondet) {
    //@ assert valid_read_string(p);
    Frama_C_show_each_valid_read_string_imprecise_offset(p);
  }

  if (nondet) {
    //@ assert !valid_string(p);
    Frama_C_show_each_invalid_string_imprecise_offset(p);
  }

  if (nondet) {
    //@ assert !valid_read_string(p);
    Frama_C_show_each_invalid_read_string_imprecise_offset(p);
  }

  // Test with a garbled mix.
  p = garbled_mix(p);

  if (nondet) {
    //@ assert valid_string(p);
    Frama_C_show_each_valid_string_garbled_mix(p);
  }

  if (nondet) {
    //@ assert valid_read_string(p);
    Frama_C_show_each_valid_read_string_garbled_mix(p);
  }

  if (nondet) {
    //@ assert !valid_string(p);
    Frama_C_show_each_invalid_string_garbled_mix(p);
  }

  if (nondet) {
    //@ assert !valid_read_string(p);
    Frama_C_show_each_invalid_read_string_garbled_mix(p);
  }

  p = NULL;
}

void main (void) {
  reduce_by_valid_string();
}
