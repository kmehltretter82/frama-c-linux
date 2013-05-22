#include "stdio.h"

void e_acsl_assert(int predicate, 
		   char *kind, 
		   char *fct, 
		   char *pred_txt, 
		   int line) 
{
  printf("%s at line %d in function %s is %s.\n\
The verified predicate was: `%s'.\n",
	 kind, line, fct, predicate ? "valid" : "invalid", pred_txt);
}
