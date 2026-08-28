/* run.config
   OPT: -machdep gcc_x86_32 -print
*/

/*
 * Linux uses GNU's omitted-middle conditional expression inside attribute
 * arguments when an optional variadic macro argument is absent.
 */
#define kernel_aligned(value) __attribute__((__aligned__(value)))

struct cacheline_group {
  unsigned char begin[0]
    kernel_aligned((0 + 0) ? : (1 << 5));
  int member;
};
