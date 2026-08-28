/* run.config
   OPT: -kernel-checks -kernel-checks-max-errno 31 -machdep gcc_x86_64
*/

#define ERR_PTR(error) ((void *)(long)(error))

void kfree(const void *pointer)
{
  (void)pointer;
}

int main(void)
{
  kfree(ERR_PTR(-31));
  kfree(ERR_PTR(-32));
  return 0;
}
