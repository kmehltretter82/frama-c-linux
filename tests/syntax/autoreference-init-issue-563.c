/* run.config
   STDOPT: #"-cpp-extra-args=-DCORRECTINIT"
   STDOPT: #"-cpp-extra-args=-DAUTOINIT"
   STDOPT: #"-cpp-extra-args=-DADDREFFECTS"
   EXIT: 1
*/

#include <stdlib.h>

struct s {
  int a;
  int b[];
};

struct _cell {
  int value;
  struct _cell *prev;
  struct _cell *next;
};

void f() {

  #ifdef CORRECTINIT
  int a[5]={ a[2], 42, a[3] };
  struct _cell arr_1[2] = {
      { 0, &arr_1[1], &arr_1[1] },
      { 1, &arr_1[0], &arr_1[0] }
    };
  // A temporary variable is created here, even if not needed.
  struct s *x = malloc(sizeof(x) + sizeof(int)*10);
  #endif

  #ifdef AUTOINIT
  // The side-effect to affect 'b' needs to be done outside the initialization
  // because Frama-C's internal AST does not allow side-effects in expressions.
  // Ideally we would like to declare 'b' and then do a undefined sequence
  // between the affectation and the initialization, but Frama-C does not allow
  // to do that trivially.
  // At the moment a temporary variable is created to do the affectation but
  // is not used affterward, so the transformation is erroneous.
  int b[4]={ b[2], 42, b[3] = 1 };
  #endif

  #ifdef ADDREFFECTS
  // The side-effect to affect 'y' is done outside the initialization for the
  // same reason than 'b'. Since 'arr_2' does not exist at this point it's
  // replaced by a temporary variable, thus the addresses won't match.
  // The solution suggested above would also fix this case.
  struct _cell *y;
  struct _cell arr_2[2] = {
      { 0, (y = &arr_2[1], &arr_2[1]), &arr_2[1] },
      { 1, &arr_2[0], &arr_2[0] }
    };
  #endif
}
