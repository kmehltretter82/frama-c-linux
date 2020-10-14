/* run.config
   PLUGIN: constant_propagation @PLUGIN@
   CMD: @frama-c@ -load-plugin slicing -load-plugin constant_propagation -load-module %{dep:libSelect.cmxs} -load-module %{dep:@PTEST_NAME@.cmxs}
   OPT: @EVA_OPTIONS@ -deps -journal-disable
*/

//@ assigns \result \from x;
int g (int x);

int f (int c, int x) {
  int y = c ? 1 : -1;
  int r;
  if (y < 0)
    r = x+y;
  else
    r = 0;
  r = g (r);
  return r;
}

int main (int x) {
  int r;
  if (x > 0)
    r = f (0, x);
  else
    r = f (1, x);
  return r;
}
