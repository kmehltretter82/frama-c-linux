/* run.config
   OPT: -machdep gcc_x86_64 -print
*/

int pointer_is_constant(void *pointer)
{
  return __builtin_constant_p(pointer);
}

int integer_is_constant(int value)
{
  return __builtin_constant_p(value);
}
