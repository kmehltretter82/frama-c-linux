/* run.config
   OPT: -machdep gcc_x86_64 -print
*/

void cold_function(void) __attribute__((cold));
void hot_function(void) __attribute__((hot));

void cold_function(void)
{
}

void hot_function(void)
{
}

void attributed_labels(int selector)
{
  cold_function();
  hot_function();

  if (selector)
    goto unlikely_path;
  return;

unlikely_path: __attribute__((cold));
}
