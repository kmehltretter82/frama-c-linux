/* run.config
*    GCC:
*    STDOPT: +"-fct-pdg main -inout "
*/
/*
 * ledit bin/toplevel.top  no_body.c -fct-pdg main
 * #use "select.ml";;
 * test "loop" (select_data "G");;
*/

int G;

int f (int a);

void loop (int x) {
  while (f(x)) {
    x++;
    G++;
  }
}

void main (void) {
  int x = 1;
  G = f(x);
  loop (x);
}
