/* run.config
   OPT: -kernel-checks -eva-slevel 20 -machdep gcc_arm64
*/

#include <stdlib.h>

struct flex_object {
  int count;
  int entries[] __attribute__((counted_by(count)));
};

struct pointer_object {
  int count;
  int *entries __attribute__((counted_by(count)));
};

static struct flex_object *make_object(void)
{
  struct flex_object *object =
    malloc(sizeof(*object) + 8 * sizeof(object->entries[0]));

  if (object) {
    int index;

    object->count = 8;
    for (index = 0; index < 8; index++)
      object->entries[index] = index;
    object->count = 4;
  }
  return object;
}

int main(void)
{
  struct flex_object *object = make_object();
  int backing[4] = { 0 };
  struct pointer_object pointer = { 4, backing };
  int *one_past;

  if (!object)
    return 0;

  object->entries[0] = 1;
  object->entries[3] = 2;
  pointer.entries[0] = object->entries[0];
  pointer.entries[3] = object->entries[3];
  *pointer.entries = 3;

  /* Forming a one-past address is not a memory access. */
  one_past = &object->entries[object->count];
  return pointer.entries[0] + (one_past != 0);
}
