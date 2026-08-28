/* run.config
   OPT: -kernel-checks -kernel-checks-err-ptr-source make_reply -machdep gcc_x86_64
   OPT: -kernel-checks -kernel-checks-err-ptr-source make_reply -machdep gcc_x86_32
   OPT: -kernel-checks -kernel-checks-bounded-entry -kernel-checks-err-ptr-source make_reply -kernel-checks-fault-errno 5 -machdep gcc_arm64
*/

#define MAX_ERRNO 4095
#define IS_ERR_VALUE(value) \
  ((unsigned long)(void *)(value) >= (unsigned long)-MAX_ERRNO)

struct sk_buff {
  int length;
};

static struct sk_buff normal_reply;

static struct sk_buff *make_reply(void)
{
  return &normal_reply;
}

void kfree_skb_reason(struct sk_buff *skb, int reason)
{
  (void)skb;
  (void)reason;
}

void kfree_skb(struct sk_buff *skb)
{
  kfree_skb_reason(skb, 0);
}

int main(void)
{
  struct sk_buff *reply = make_reply();
  int error = 0;

  if (IS_ERR_VALUE(reply)) {
    error = (int)(long)reply;
    reply = (void *)0;
    goto error;
  }
  return 0;

error:
  kfree_skb(reply);
  return error;
}
