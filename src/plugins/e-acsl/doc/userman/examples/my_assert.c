#include "stdio.h"

extern int __e_acsl_sound_verdict;

void __e_acsl_assert(int pred, const char *kind, const char *func_name,
                     const char *pred_text, const char *file, int line) {
  printf("%s in file %s at line %d in function %s is %s (%s).\n\
The verified predicate was: `%s'.\n",
    kind,
    file,
    line,
    func_name,
    pred ? "valid" : "invalid",
    __e_acsl_sound_verdict ? "trustworthy" : "UNTRUSTWORTHY",
    pred_text);
}
