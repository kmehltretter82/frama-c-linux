/* run.config
   OPT: -machdep gcc_x86_64 -print
*/

struct offset_container {
  int prefix;
  long elements[4];
};

_Static_assert(__builtin_offsetof(struct offset_container, elements[2]) == 24,
               "constant array index remains a constant offset");

unsigned long dynamic_offset(int index)
{
  return __builtin_offsetof(struct offset_container, elements[index]);
}

unsigned long side_effect_offset(int *index)
{
  return __builtin_offsetof(struct offset_container, elements[(*index)++]);
}
