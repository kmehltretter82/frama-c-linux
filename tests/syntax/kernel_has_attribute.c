/* run.config
   OPT: -machdep gcc_x86_64 -print
*/

char annotated_global[8] __attribute__((__nonstring__));
char string_global[8];

struct attribute_container {
  char raw[8] __attribute__((nonstring));
  char text[8];
};

_Static_assert(__builtin_has_attribute(annotated_global, nonstring),
               "global carries nonstring");
_Static_assert(!__builtin_has_attribute(string_global, nonstring),
               "ordinary global does not carry nonstring");

int attribute_results(struct attribute_container *container)
{
  return 10 * __builtin_has_attribute(container->raw, __nonstring__) +
         __builtin_has_attribute(container->text, nonstring);
}
