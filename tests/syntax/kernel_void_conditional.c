/* run.config
   OPT: -machdep gcc_x86_64 -print
*/

void delay(unsigned long usecs);

#define kernel_delay(msecs)                                             \
  ((__builtin_constant_p(msecs) && (msecs) <= 5)                        \
     ? delay((msecs) * 1000)                                            \
     : ({ unsigned long __ms = (msecs);                                 \
          while (__ms--)                                                \
            delay(1000); }))

void constant_delay(void)
{
  kernel_delay(1);
}

void variable_delay(unsigned long msecs)
{
  kernel_delay(msecs);
}
