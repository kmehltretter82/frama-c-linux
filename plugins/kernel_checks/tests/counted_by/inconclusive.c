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
  }
  return object;
}

int main(int selector)
{
  struct flex_object *object = make_object();
  int backing[8] = { 0 };
  struct pointer_object pointer = { selector ? 2 : 8, backing };
  int index;

  if (!object)
    return 0;

  /* Both correlated outcomes are safe, but Eva exposes joined ranges here. */
  object->count = selector ? 4 : 8;
  index = selector ? 3 : 7;
  sink = object->entries[index];

  /* Each access below is invalid on one path and valid on another. */
  object->count = selector ? 2 : 8;
  sink = object->entries[3];
  object->count = 4;
  index = selector ? -1 : 3;
  sink = object->entries[index];
  sink = pointer.entries[3];

  /* A value-changing cast is not structural equality with the counter. */
  object->count = 260;
  sink = object->entries[(unsigned char)object->count];
  return sink;
}
