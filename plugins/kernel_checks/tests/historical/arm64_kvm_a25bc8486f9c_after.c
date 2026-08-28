/* run.config
   OPT: -eva -eva-slevel 10 -machdep gcc_arm64
   FILTER: sed -e 's/[[:space:]]*$//'
*/

/* Reduced replay of Linux commit a25bc8486f9c0 after the size guard. */

typedef unsigned long long u64;

#define KVM_REG_SIZE_SHIFT 52
#define KVM_REG_SIZE_MASK  0x00f0000000000000ULL
#define KVM_REG_SIZE(id) \
  (1U << (((id) & KVM_REG_SIZE_MASK) >> KVM_REG_SIZE_SHIFT))
#define KVM_REG_SIZE_U128  0x0040000000000000ULL

struct kvm_one_reg {
  u64 id;
  u64 addr;
};

/*@
  requires destination_extent:
    bytes == 0 || \valid(((unsigned char *)to) + (0 .. bytes - 1));
  requires source_extent:
    bytes == 0 || \valid_read(((const unsigned char *)from) +
                              (0 .. bytes - 1));
  assigns \result,
          ((unsigned char *)to)[0 .. bytes - 1]
    \from bytes, ((const unsigned char *)from)[0 .. bytes - 1];
  ensures copy_succeeds: \result == 0;
 */
unsigned long copy_from_user(void *to, const void *from,
                             unsigned long bytes);

static unsigned char user_value[16];

static int kvm_arm_set_fw_reg_replay(const struct kvm_one_reg *reg)
{
  void *uaddr = (void *)(unsigned long)reg->addr;
  u64 val;

  if (KVM_REG_SIZE(reg->id) != sizeof(val))
    return -2;
  if (copy_from_user(&val, uaddr, KVM_REG_SIZE(reg->id)))
    return -14;

  return -2;
}

int main(void)
{
  struct kvm_one_reg reg = {
    .id = KVM_REG_SIZE_U128,
    .addr = (u64)(unsigned long)user_value,
  };

  return kvm_arm_set_fw_reg_replay(&reg);
}
