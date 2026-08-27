const int const_int;
volatile int volatile_int;
int * const const_pointer;
const int *pointer_to_const;

__typeof_unqual__(volatile_int) from_gnu_expression;
__typeof_unqual(const int) from_gnu_type;
__typeof_unqual__(const_pointer) unqualified_pointer;
__typeof_unqual__(pointer_to_const) pointer_with_qualified_target;
