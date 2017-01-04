#include "stdio.h"

void __e_acsl_assert(int pred, char *kind,
                     char *func_name, char *pred_text, int line) {
  printf("%s at line %d in function %s is %s.\n\
The verified predicate was: `%s'.\n",
  kind, line, func_name, pred ? "valid" : "invalid", pred_text);
}
