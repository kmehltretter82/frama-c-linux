/* run.config
   OPT: -print %{dep:third.c} %{dep:second.c} -journal-disable
*/
/*@ behavior b:
  requires \valid(first);
  ensures \result == 0;*/
int bar(int *first);

void main (int * c) {
  bar(c);
}
