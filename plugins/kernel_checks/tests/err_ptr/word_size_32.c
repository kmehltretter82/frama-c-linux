/* run.config
   OPT: -kernel-checks -machdep gcc_x86_32
*/

#define ERR_PTR(error) ((void *)(long)(error))

void kfree(const void *pointer)
{
  (void)pointer;
}

int main(void)
{
  kfree(ERR_PTR(-1));
  return 0;
}
