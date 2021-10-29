/* run.config
   OPT: -print tests/spec/third.c tests/spec/second.c
*/
/*@ behavior b:
  requires \valid(first);
  ensures \result == 0;*/
int bar(int *first);

void main (int * c) {
  bar(c);
}
