/* run.config
   OPT: -rte -warn-unsigned-overflow -print -journal-disable -machdep x86_32
   OPT: -rte -warn-unsigned-overflow -print -journal-disable -machdep x86_64
*/
unsigned long f(unsigned int n)
{
  return n * sizeof(unsigned long);
}
