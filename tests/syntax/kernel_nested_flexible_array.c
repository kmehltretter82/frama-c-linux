/* run.config
   OPT: -machdep gcc_x86_32 -print
*/

struct flex_payload {
  unsigned int length;
  unsigned char data[];
};

/* GCC accepts a type containing a flexible array as a non-final field. */
struct kernel_control_block {
  int prefix;
  struct flex_payload payload;
  int flags;
};

int kernel_control_flags(const struct kernel_control_block *control)
{
  return control->flags;
}
