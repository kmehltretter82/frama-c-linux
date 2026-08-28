/* run.config
   OPT: -kernel-checks -eva-slevel 10 -machdep gcc_x86_64
*/

/* Reduced replay of Linux commit ee30dd2909d8b after the fix. */

#define MAX_ERRNO 4095
#define ERR_PTR(error) ((void *)(long)(error))
#define IS_ERR_VALUE(value) \
  ((unsigned long)(void *)(value) >= (unsigned long)-MAX_ERRNO)

struct sk_buff {
  int length;
};

void kfree_skb(struct sk_buff *skb)
{
  (void)skb;
}

static struct sk_buff *build_reply(int fail)
{
  static struct sk_buff reply;
  return fail ? ERR_PTR(-12) : &reply;
}

static int ovs_flow_cmd_set_replay(int fail)
{
  struct sk_buff *reply = build_reply(fail);
  int error = 0;

  if (IS_ERR_VALUE(reply)) {
    error = (int)(long)reply;
    reply = 0;
    goto err_unlock_ovs;
  }
  return 0;

err_unlock_ovs:
  kfree_skb(reply);
  return error;
}

int main(void)
{
  return ovs_flow_cmd_set_replay(1);
}
