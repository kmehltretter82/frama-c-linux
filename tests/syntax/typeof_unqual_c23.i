/* run.config
   OPT: -print -std=c23
*/

const int const_int;
int * const const_pointer;
const int *pointer_to_const;

typeof_unqual(const_int) from_expression;
typeof_unqual(const int) from_type;
typeof_unqual(const_pointer) unqualified_pointer;
typeof_unqual(pointer_to_const) pointer_with_qualified_target;
