/* run.config
   OPT: -machdep gcc_x86_64 -print
*/

void void_callee(void)
{
}

void forward_void_call(void)
{
  return void_callee();
}

void forward_void_cast(int value)
{
  return (void)value;
}
