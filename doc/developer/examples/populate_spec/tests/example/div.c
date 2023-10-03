/* run.config
   OPT: -check -generated-spec-mode mymode -then-last -print
*/

/*@ behavior A:
      assigns *bar \from bar;
    behavior B:
      assigns \nothing;
    complete behaviors;
  @*/
int f(int* bar);

int g(){
  int foo = 42;
  return f(&foo);
}
