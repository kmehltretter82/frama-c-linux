/* run.config
   OPT: -machdep gcc_x86_64 -print
*/

void consume_const_volatile(unsigned long const volatile *value);
void consume_const(unsigned long const *value);

void add_one_qualifier(unsigned long const *value)
{
  consume_const_volatile(value);
}

void discard_one_qualifier(unsigned long const volatile *value)
{
  consume_const(value);
}
