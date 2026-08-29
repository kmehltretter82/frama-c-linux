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

static volatile int sink;

static struct flex_object *make_object(void)
{
  struct flex_object *object =
    malloc(sizeof(*object) + 8 * sizeof(object->entries[0]));

  if (object) {
    int index;

    object->count = 8;
    for (index = 0; index < 8; index++)
      object->entries[index] = 0;
    object->count = 4;
  }
  return object;
}

int main(int selector)
{
  struct flex_object *object = make_object();
  int backing[8] = { 0 };
  struct pointer_object pointer = { 4, backing };

  if (!object)
    return 0;

  object->entries[4] = 1;
  sink = object->entries[-1];

  object->count = 0;
  sink = object->entries[0];
  object->count = -3;
  sink = object->entries[0];

  object->count = selector ? 4 : 7;
  sink = object->entries[object->count];

  pointer.entries[4] = 1;
  return sink;
}
