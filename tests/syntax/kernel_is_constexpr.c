/* run.config
   OPT: -machdep gcc_x86_64 -print
*/

#define kernel_is_constexpr(x) \
  (sizeof(int) == sizeof(*(8 ? ((void *)((long)(x) * 0L)) : (int *)8)))

#define kernel_const_true(x) \
  __builtin_choose_expr(kernel_is_constexpr(x), (x), 0)

int nonconstant_value;

_Static_assert(kernel_is_constexpr(4), "literal is a constant expression");
_Static_assert(!kernel_is_constexpr(nonconstant_value),
               "object value is not a constant expression");
_Static_assert(kernel_const_true(1), "constant true remains true");
_Static_assert(!kernel_const_true(nonconstant_value),
               "nonconstant expression selects constant false");

void check_parameter(int parameter)
{
  _Static_assert(!kernel_is_constexpr(parameter),
                 "parameter is not a constant expression");
  _Static_assert(!__builtin_choose_expr(kernel_is_constexpr(parameter),
                                        parameter > 3, 0),
                 "the unselected nonconstant branch is not evaluated");
}
