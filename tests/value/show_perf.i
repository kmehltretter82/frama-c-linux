/* run.config*
   FILTER: sed -e 's/\([0-9.]\+\(%\|s\)\)/?\2/g'
   STDOPT: +"-eva-show-perf"
*/

/* This example is kept minimal to ensure the stability of the output
   of -eva-show-perf. */

volatile int nondet;

typedef struct S {
  unsigned int length;
  unsigned int max;
} result;

int compute_next(unsigned int x) {
  return (x % 2 == 0) ? x / 2 : 3*x + 1;
}

result collatz(unsigned int n) {
  unsigned int i = 0;
  unsigned int v = n;
  unsigned int max = n;
  //@ loop unroll 100;
  for (i = 0; i < 100; i++) {
    if (v == 1) break;
    if (v > max) max = v;
    v = compute_next(v);
  }
  result r = { .length = i, .max = max };
  return r;
}

void print_collatz(unsigned int n) {
  result r = collatz(n); // 1 call to collatz
  r = collatz(n);        // 1 call cached by memexec
  Frama_C_show_each(n, r.length, r.max);
}

void main (void) {
  print_collatz(7); // 16 calls to [compute_next] for n = 7.
}
