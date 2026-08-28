/* run.config
   OPT: -machdep gcc_x86_32 -print
*/

/*
 * Linux macros can leave a trailing comma when an optional output operand
 * expands to nothing. GCC accepts the resulting extended-asm syntax.
 */
void kernel_asm_trailing_comma(long stack_pointer, long value)
{
  asm volatile("call target"
               : "+r" (stack_pointer),
               : "S" (value)
               : "eax", "memory");
}
