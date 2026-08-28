/* run.config
   OPT: -kernel-checks -eva-slevel 20 -machdep gcc_x86_64
*/

#define MAX_ERRNO 4095
#define ERR_PTR(error) ((void *)(long)(error))
#define IS_ERR_VALUE(value) \
  ((unsigned long)(void *)(value) >= (unsigned long)-MAX_ERRNO)

struct item {
  int value;
};

typedef void (*callback_t)(void);

void kfree(const void *pointer)
{
  (void)pointer;
}

void dev_kfree_skb_any_reason(const void *pointer, int reason)
{
  (void)pointer;
  (void)reason;
}

void devm_kfree(void *device, const void *pointer)
{
  (void)device;
  (void)pointer;
}

static int checked_read(struct item *pointer)
{
  if (IS_ERR_VALUE(pointer))
    return 0;
  return pointer->value;
}

int main(int selector)
{
  struct item object = { 0 };
  struct item *encoded = ERR_PTR(-22);
  struct item *boundary = ERR_PTR(-MAX_ERRNO);
  struct item *outside = ERR_PTR(-(MAX_ERRNO + 1));
  struct item *maybe = selector ? encoded : &object;
  int *address_only = &encoded->value;

  kfree(&object);
  kfree((void *)0);
  kfree(maybe);
  kfree(outside);
  object.value = checked_read(maybe) + (address_only != 0);

  kfree(encoded);
  kfree(boundary);
  dev_kfree_skb_any_reason(encoded, 1);
  devm_kfree(&object, boundary);

  if (selector == 2) {
    callback_t callback = ERR_PTR(-5);
    callback();
  }
  if (selector)
    return encoded->value;
  boundary->value = 1;
  return object.value;
}
