/* run.config
   OPT: -machdep gcc_arm64 -print
*/

typedef unsigned long machine_word;

extern int incomplete_array[];
static int complete_array[4];

int callback(void);

typedef __typeof__((machine_word)incomplete_array) array_address_type;
typedef __typeof__((machine_word)callback) function_address_type;

_Static_assert(sizeof(array_address_type) == sizeof(machine_word),
               "the cast operand decays inside typeof");
_Static_assert(sizeof(function_address_type) == sizeof(machine_word),
               "the function designator decays inside typeof");

machine_word array_address(int use_complete)
{
  return use_complete
    ? (machine_word)complete_array
    : (machine_word)incomplete_array;
}

machine_word function_address(void)
{
  return (machine_word)callback;
}

machine_word cast_size(void)
{
  return sizeof((machine_word)incomplete_array);
}
