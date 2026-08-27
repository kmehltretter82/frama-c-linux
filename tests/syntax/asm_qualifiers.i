int asm_inline(int value)
{
  asm __inline__ volatile ("" : "+r" (value));
  return value;
}

int asm_volatile_goto(void)
{
  asm volatile goto ("" : : : : target);
  return 0;

target:
  return 1;
}
